/*
 * setup_libCacheSim.c  –  multi-threaded parallel version of setup_libCacheSim.sh
 *
 * Compile:
 *   gcc -O2 -Wall -pthread -o setup_libCacheSim setup_libCacheSim.c
 *
 * Run:
 *   ./setup_libCacheSim
 *
 * Every node gets its own thread so libCacheSim + distComp are installed on
 * all nodes concurrently.  A mutex serialises terminal output.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>

/* ─── colour codes ────────────────────────────────────────────────── */
#define RED    "\033[0;31m"
#define GREEN  "\033[0;32m"
#define YELLOW "\033[1;33m"
#define NC     "\033[0m"

/* ─── node list ───────────────────────────────────────────────────── */
static const char *NODES[] = {
    "node0",  "node1",  "node2",  "node3",
    "node4",  "node5",  "node6",  "node7",
    "node8",  "node9",  "node10", "node11",
    "node12", "node13", "node14", "node15",
    "node16", "node17", "node18", "node19",
    "node20", "node21", "node22", "node23",
    "node24", "node25", "node26", "node27",
    "node28", "node29", "node30", "node31",
};
#define NUM_NODES ((int)(sizeof(NODES) / sizeof(NODES[0])))

/* ─── remote scripts (verbatim from the .sh) ─────────────────────── */

static const char *LIBCACHESIM_SCRIPT =
    "set -e\n"
    "if ! command -v cmake &>/dev/null; then\n"
    "    echo '[+] Installing cmake...'\n"
    "    if command -v apt &>/dev/null; then\n"
    "        sudo apt update && sudo apt install -y cmake\n"
    "    elif command -v yum &>/dev/null; then\n"
    "        sudo yum install -y cmake\n"
    "    elif command -v dnf &>/dev/null; then\n"
    "        sudo dnf install -y cmake\n"
    "    else\n"
    "        echo '[!] No known package manager found to install cmake.'\n"
    "        exit 1\n"
    "    fi\n"
    "else\n"
    "    echo '[=] cmake already installed.'\n"
    "fi\n"
    "\n"
    "if [ ! -d \"$HOME/libCacheSim\" ]; then\n"
    "    echo '[+] Cloning and building libCacheSim...'\n"
    "    git clone https://SeverinaZheng:x@github.com/SeverinaZheng/libCacheSim_primitive.git \"$HOME/libCacheSim\"\n"
    "    cd ~/libCacheSim/scripts\n"
    "    bash install_dependency.sh\n"
    "    bash install_libcachesim.sh\n"
    "else\n"
    "    echo '[=] libCacheSim already exists, skipping clone and build.'\n"
    "fi\n";

static const char *DISTCOMP_SCRIPT =
    "set -e\n"
    "sudo apt-get install -y python3-pip python3-venv python3-full pssh\n"
    "\n"
    "# Install redis and psutil inside a venv to avoid PEP 668\n"
    "VENV=\"$HOME/.parallel-ssh-venv\"\n"
    "if [ ! -d \"$VENV\" ]; then\n"
    "    python3 -m venv \"$VENV\"\n"
    "fi\n"
    "\"$VENV/bin/pip\" install --upgrade pip\n"
    "\"$VENV/bin/pip\" install redis psutil\n"
    "\n"
    "if [ ! -d \"$HOME/distComp\" ]; then\n"
    "    echo '[+] Cloning and setting up distComp...'\n"
    "    git clone https://SeverinaZheng:x@github.com/1a1a11a/distComp.git\n"
    "    cd distComp\n"
    "    if [ \"$(hostname)\" == \"node0\" ]; then\n"
    "        bash ./redis.sh\n"
    "    fi\n"
    "else\n"
    "    echo '[=] distComp already set up.'\n"
    "fi\n";

/* ─── shared state ────────────────────────────────────────────────── */
static pthread_mutex_t print_mutex  = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t result_mutex = PTHREAD_MUTEX_INITIALIZER;

static int successful_count = 0;
static int failed_count     = 0;
static char successful_nodes[NUM_NODES][32];
static char failed_nodes[NUM_NODES][32];

/* ─── helpers ─────────────────────────────────────────────────────── */
#define MAX_CMD 4096

static void print_info(const char *node, const char *msg) {
    pthread_mutex_lock(&print_mutex);
    printf(GREEN "[INFO]" NC " [%s] %s\n", node, msg);
    fflush(stdout);
    pthread_mutex_unlock(&print_mutex);
}

static void print_err(const char *node, const char *msg) {
    pthread_mutex_lock(&print_mutex);
    fprintf(stderr, RED "[ERROR]" NC " [%s] %s\n", node, msg);
    fflush(stderr);
    pthread_mutex_unlock(&print_mutex);
}

/*
 * Write `script` to a temp file, then pipe it to `user@node` via ssh.
 * Returns 0 on success, non-zero on failure.
 */
static int ssh_script(const char *user, const char *node, const char *script) {
    char tmpfile[] = "/tmp/setup_libcachesim_XXXXXX";
    int fd = mkstemp(tmpfile);
    if (fd < 0) return -1;
    ssize_t written = write(fd, script, strlen(script));
    close(fd);
    if (written < 0) { unlink(tmpfile); return -1; }

    char cmd[MAX_CMD];
    snprintf(cmd, sizeof(cmd),
        "ssh -o StrictHostKeyChecking=accept-new '%s@%s' bash < '%s'",
        user, node, tmpfile);

    int ret = system(cmd);
    unlink(tmpfile);
    return ret;
}

/* ─── thread entry point ─────────────────────────────────────────── */

typedef struct {
    const char *node;
    char        user[64];
} thread_arg_t;

static void *process_node(void *arg) {
    thread_arg_t *a = (thread_arg_t *)arg;
    const char   *node = a->node;
    const char   *user = a->user;

    int ok = 0;

    /* Step 1: libCacheSim */
    print_info(node, "Installing cmake + cloning/building libCacheSim...");
    if (ssh_script(user, node, LIBCACHESIM_SCRIPT) != 0) {
        print_err(node, "libCacheSim setup failed");
        goto done;
    }
    print_info(node, "libCacheSim setup completed");

    /* Step 2: distComp */
    print_info(node, "Installing distComp...");
    if (ssh_script(user, node, DISTCOMP_SCRIPT) != 0) {
        print_err(node, "distComp setup failed");
        goto done;
    }
    print_info(node, "distComp setup completed");

    ok = 1;

done:
    pthread_mutex_lock(&result_mutex);
    if (ok)
        strncpy(successful_nodes[successful_count++], node, 31);
    else
        strncpy(failed_nodes[failed_count++], node, 31);
    pthread_mutex_unlock(&result_mutex);

    free(a);
    return NULL;
}

/* ─── main ───────────────────────────────────────────────────────── */

int main(void) {
    const char *user = getenv("USER");
    if (!user || user[0] == '\0') user = getenv("LOGNAME");
    if (!user || user[0] == '\0') {
        fprintf(stderr, RED "[ERROR]" NC " Could not determine $USER\n");
        return 1;
    }

    printf(GREEN "[INFO]" NC " Starting parallel setup for %d nodes as user '%s'...\n",
           NUM_NODES, user);

    pthread_t threads[NUM_NODES];

    for (int i = 0; i < NUM_NODES; i++) {
        thread_arg_t *arg = malloc(sizeof(thread_arg_t));
        arg->node = NODES[i];
        strncpy(arg->user, user, sizeof(arg->user) - 1);
        arg->user[sizeof(arg->user) - 1] = '\0';

        if (pthread_create(&threads[i], NULL, process_node, arg) != 0) {
            fprintf(stderr, RED "[ERROR]" NC " pthread_create failed for %s\n", NODES[i]);
            free(arg);
            /* Count as failed immediately */
            pthread_mutex_lock(&result_mutex);
            strncpy(failed_nodes[failed_count++], NODES[i], 31);
            pthread_mutex_unlock(&result_mutex);
            threads[i] = 0;
        }
    }

    /* Wait for all threads */
    for (int i = 0; i < NUM_NODES; i++) {
        if (threads[i])
            pthread_join(threads[i], NULL);
    }

    /* Summary */
    printf("\n" GREEN "[INFO]" NC " === SETUP SUMMARY ===\n");
    printf(GREEN "[INFO]" NC " Successfully configured: %d / %d nodes\n",
           successful_count, NUM_NODES);
    for (int i = 0; i < successful_count; i++)
        printf("  " GREEN "✓" NC " %s\n", successful_nodes[i]);

    if (failed_count > 0) {
        printf(RED "[ERROR]" NC " Failed: %d node(s)\n", failed_count);
        for (int i = 0; i < failed_count; i++)
            printf("  " RED "✗" NC " %s\n", failed_nodes[i]);
    }

    printf(GREEN "[INFO]" NC " Done.\n");
    return failed_count > 0 ? 1 : 0;
}
