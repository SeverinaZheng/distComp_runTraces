#!/usr/bin/env python3

"""Generate MRC by invoking cachesim with a predefined cache size sweep.

This script:
1) Changes directory to the libCacheSim build folder.
2) Builds a cache-size list with two segments:
   - Step 0.02 from 0.001 up to (and including) 0.1
   - Step 0.1  from 0.1   up to (and including) 0.5
3) Runs cachesim with the provided algorithms and fixed trace path, ignoring
   object size.

Example:
  python3 generate_MRC.py --algorithms fifo,arc
"""

import argparse
import os
import subprocess
from typing import Dict, List, Optional, Tuple

import matplotlib.pyplot as plt


BUILD_DIR = "/users/YJZheng/libCacheSim/_build"


def build_cache_sizes() -> List[float]:
	sizes = []

	# 0.001 to 0.005 with step 0.0002
	# val = 0.001
	# while val <= 1.0001:  # tolerance for floating point
	# 	sizes.append(round(val, 6))
	# 	val += 0.02

	# val = 0.41
	# while val <= 0.8000001:  # tolerance for floating point
	# 	sizes.append(round(val, 6))
	# 	val += 0.02

	# val = 0.82
	# while val <= 1.000001:  # tolerance for floating point
	# 	sizes.append(round(val, 6))
	# 	val += 0.05


	sizes.append(0.001)
	sizes.append(0.01)
	sizes.append(0.05)
	sizes.append(0.1)
	sizes.append(0.3)
	sizes.append(0.5)
	sizes.append(0.7)
	sizes.append(0.9)
	sizes.append(1.0)
	sizes = sorted(set(sizes))
	return sizes


def parse_cache_sizes_arg(cache_sizes_arg: str) -> List[float]:
	"""Parse a comma-separated cache size string into a float list."""
	parsed_sizes = []
	for token in cache_sizes_arg.split(","):
		token = token.strip()
		if not token:
			continue
		try:
			parsed_sizes.append(float(token))
		except ValueError as exc:
			raise ValueError(f"Invalid cache size '{token}' in --cache-sizes") from exc
	if not parsed_sizes:
		raise ValueError("No valid cache sizes parsed from --cache-sizes")
	return parsed_sizes


def run_cachesim(algorithms: str, trace_path: str, cache_sizes: List[float]) -> str:
	print(f"Changing directory to {BUILD_DIR}")
	os.chdir(BUILD_DIR)

	trace_basename = os.path.basename(trace_path)
	target_file = os.path.join(BUILD_DIR, "result", f"{trace_basename}.cachesim")
	if os.path.exists(target_file):
		print(f"Result already exists at {target_file}, skipping cachesim run.")
		return target_file

	def chunked(lst, size):
		for i in range(0, len(lst), size):
			yield lst[i:i + size]

	for chunk in chunked(cache_sizes, 5):
		cache_sizes_arg = ",".join(f"{c:.6f}" for c in chunk)
		cmd = [
			"./bin/cachesim",
			trace_path,
			"lcs",
			algorithms,
			cache_sizes_arg,
			"--ignore-obj-size",
			"1",
		]

		print("Running:", " ".join(cmd))
		result = subprocess.run(cmd)
		if result.returncode != 0:
			raise SystemExit(f"cachesim failed with exit code {result.returncode}")

	return target_file


def _parse_result_file(result_file: str) -> Dict[str, List[Tuple[float, float]]]:
	if not os.path.exists(result_file):
		raise FileNotFoundError(f"Result file not found: {result_file}")

	alg_data: Dict[str, List[Tuple[float, float]]] = {}
	with open(result_file) as f:
		for line in f:
			line = line.strip()
			if not line or line.startswith("#"):
				continue
			parts = line.split()
			if len(parts) < 10:
				continue
			trace_path = parts[0]
			alg = parts[1]
			cache_size_token = parts[4].rstrip(",")
			miss_ratio_token = parts[9].rstrip(",")
			try:
				cache_size = float(cache_size_token)
				miss_ratio = float(miss_ratio_token)
			except ValueError:
				print(f"Warning: skip malformed line: {line}")
				continue
			alg_data.setdefault(alg, []).append((cache_size, miss_ratio))

	if not alg_data:
		raise ValueError(f"No data parsed from {result_file}")
	return alg_data


def plot_mrc(
	result_file: str,
	cache_sizes_ratio: List[float],
	ymin: Optional[float] = None,
	ymax: Optional[float] = None,
	xmax: Optional[float] = None,
	algorithms_filter: Optional[List[str]] = None,
):
	alg_data = _parse_result_file(result_file)
	if algorithms_filter:
		allowed = {alg.strip() for alg in algorithms_filter if alg.strip()}
		alg_data = {alg: entries for alg, entries in alg_data.items() if alg in allowed}
		if not alg_data:
			raise ValueError("No matching algorithms found in result for requested filter")

	output_dir = os.path.join(BUILD_DIR, "result/MRC")
	os.makedirs(output_dir, exist_ok=True)

	# Build a mapping from actual cache size to ratio (best-effort by ordering)
	actual_sizes_sorted = sorted({size for entries in alg_data.values() for size, _ in entries})
	ratios_sorted = sorted(cache_sizes_ratio)
	if len(actual_sizes_sorted) != len(ratios_sorted):
		print(
			f"Warning: actual cache sizes ({len(actual_sizes_sorted)}) != ratio list ({len(ratios_sorted)})."
			" Mapping will truncate to min length."
		)
	size_to_ratio = {}
	for size, ratio in zip(actual_sizes_sorted, ratios_sorted):
		size_to_ratio[size] = ratio

	combined_data: Dict[str, Tuple[List[float], List[float]]] = {}
	for alg, entries in alg_data.items():
		entries.sort(key=lambda x: x[0])
		x_vals = []
		y_vals = []
		for size, miss_ratio in entries:
			ratio = size_to_ratio.get(size)
			if ratio is None:
				# fallback: normalize by max size
				ratio = size / actual_sizes_sorted[-1] if actual_sizes_sorted else size
			x_vals.append(ratio)
			y_vals.append(miss_ratio)

		plt.figure(figsize=(10, 6))
		plt.plot(x_vals, y_vals, marker='o')
		plt.title(f"Miss Ratio Curve - {alg}", fontsize=22)
		plt.xlabel("Cache size (ratio)", fontsize=20)
		plt.ylabel("Miss ratio", fontsize=20)
		plt.grid(True)

		ax = plt.gca()
		ax.tick_params(axis='both', labelsize=18)

		if ymin is not None or ymax is not None:
			current_bottom, current_top = ax.get_ylim()
			ax.set_ylim(
				ymin if ymin is not None else current_bottom,
				ymax if ymax is not None else current_top,
			)

		if xmax is not None:
			ax.set_xlim(0, xmax)
		outfile = os.path.join(output_dir, f"{alg}.pdf")
		plt.savefig(outfile, bbox_inches="tight", format='pdf')
		plt.close()
		print(f"Saved MRC plot to {outfile}")

		combined_data.setdefault(alg, (x_vals, y_vals))

	if combined_data:
		plt.figure(figsize=(10, 6))
		marker_cycle = ['s', '^', 'D', 'v', '>', '<', 'p', 'h', '*', 'x']
		color_cycle = plt.cm.get_cmap('tab20', len(combined_data))
		for idx, (alg, (x_vals, y_vals)) in enumerate(combined_data.items()):
			marker = marker_cycle[idx % len(marker_cycle)]
			color = color_cycle(idx % color_cycle.N)
			plt.plot(
				x_vals,
				y_vals,
				marker=marker,
				markersize=4,
				linewidth=1.5,
				label=alg,
				color=color,
			)

		plt.title("Miss Ratio Curves (All Algorithms)", fontsize=22)
		plt.xlabel("Cache size (ratio)", fontsize=20)
		plt.ylabel("Miss ratio", fontsize=20)
		plt.grid(True)

		ax = plt.gca()
		ax.tick_params(axis='both', labelsize=18)

		if ymin is not None or ymax is not None:
			current_bottom, current_top = ax.get_ylim()
			ax.set_ylim(
				ymin if ymin is not None else current_bottom,
				ymax if ymax is not None else current_top,
			)

		if xmax is not None:
			ax.set_xlim(0, xmax)
		else:
			ax.set_xlim(left=0)


		plt.legend(fontsize=12, loc='upper left', bbox_to_anchor=(1.02, 1), borderaxespad=0.0)
		outfile = os.path.join(output_dir, "MRC_all.pdf")
		plt.savefig(outfile, bbox_inches="tight", format='pdf')
		plt.close()
		print(f"Saved combined MRC plot to {outfile}")


def main():
	parser = argparse.ArgumentParser(description="Run cachesim to generate MRC")
	parser.add_argument(
		"--algorithms",
		type=str,
		default="FIFO,Belady,LRU,ARC,CAR,Clock,GDSF,Hyperbolic,LFU,LHD,LIRS,Random,TwoQ,Lecar,Sieve",  # Default algorithms
		help="Comma-separated list of algorithms to run (e.g., fifo,arc)",
	)
	parser.add_argument(
		"--tracepath",
		type=str,
		default=os.path.join(BUILD_DIR, "alibabaBlock_23_filtered_trace.lcs.zst"),
		help="Path to the trace file (default: _build_dbg/alibabaBlock_23_filtered_trace.lcs.zst)",
	)
	parser.add_argument(
		"--ymin",
		type=float,
		default=None,
		help="Optional lower bound for the miss-ratio axis",
	)
	parser.add_argument(
		"--ymax",
		type=float,
		default=None,
		help="Optional upper bound for the miss-ratio axis",
	)
	parser.add_argument(
		"--xmax",
		type=float,
		default=None,
		help="Optional upper bound for the cache-size ratio axis (x-axis starts at 0)",
	)
	parser.add_argument(
		"--cache-sizes",
		type=str,
		default=None,
		help="Comma-separated list of cache sizes to simulate (overrides built list)",
	)
	args = parser.parse_args()
	if args.cache_sizes:
		cache_sizes = parse_cache_sizes_arg(args.cache_sizes)
	else:
		cache_sizes = build_cache_sizes()
	result_path = run_cachesim(args.algorithms, args.tracepath, cache_sizes)
	if result_path:
		plot_mrc(
			result_path,
			cache_sizes,
			ymin=args.ymin,
			ymax=args.ymax,
			xmax=args.xmax,
			algorithms_filter=args.algorithms.split(",") if args.algorithms else None,
		)


if __name__ == "__main__":
	main()

