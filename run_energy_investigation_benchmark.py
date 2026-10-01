#!/usr/bin/env python3
"""
SiriEdge — Comprehensive Battery Energy & Resource Profiler
Profiles CPU, Mach Wakeups, Context Switches, Energy Score (POWER),
Metal Draw/CmdBuffer/Presented rates, and ScreenCaptureKit audio telemetry.
"""

import subprocess
import time
import os
import sys
import fcntl
import json
import re

APP_BINARY = "./SiriEdge.app/Contents/MacOS/SiriEdge"

def profile_condition(name, args, duration_sec=15, sample_interval=1):
    print(f"\n================================================================================")
    print(f"🔬 PROFILING: {name}")
    print(f"   Args: {args} | Duration: {duration_sec}s | Interval: {sample_interval}s")
    print(f"================================================================================")
    
    subprocess.run(["pkill", "-9", "-f", "SiriEdge"], capture_output=True)
    time.sleep(0.5)
    
    cmd = [APP_BINARY, "--telemetry-log"] + args
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    pid = proc.pid
    
    # Non-blocking stdout read
    fl = fcntl.fcntl(proc.stdout.fileno(), fcntl.F_GETFL)
    fcntl.fcntl(proc.stdout.fileno(), fcntl.F_SETFL, fl | os.O_NONBLOCK)
    
    # Wait for startup
    time.sleep(1.5)
    
    # Run top sampler
    sample_count = max(int(duration_sec / sample_interval), 2)
    top_proc = subprocess.Popen(
        ["top", "-pid", str(pid), "-stats", "pid,command,cpu,idlew,power,csw", "-l", str(sample_count), "-s", str(sample_interval)],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    
    telemetry_snapshots = []
    top_samples = []
    
    start_time = time.time()
    while (time.time() - start_time) < (duration_sec + 2.0) and top_proc.poll() is None:
        try:
            chunk = proc.stdout.read()
            if chunk:
                for line in chunk.splitlines():
                    line = line.strip()
                    if "[SiriEdge Telemetry]" in line:
                        telemetry_snapshots.append(line)
        except (IOError, TypeError):
            pass
        time.sleep(0.2)
        
    top_out, _ = top_proc.communicate()
    proc.terminate()
    try:
        proc.wait(timeout=1.0)
    except:
        proc.kill()
        
    # Parse top output
    cpu_vals = []
    idlew_vals = []
    power_vals = []
    csw_vals = []
    
    for line in top_out.splitlines():
        # Match PID line: e.g. "2487 SiriEdge 0.0 29 0.0 1426"
        parts = line.split()
        if len(parts) >= 6 and parts[0] == str(pid):
            try:
                cpu = float(parts[2].replace("+", ""))
                idlew = int(parts[3].replace("+", ""))
                power = float(parts[4].replace("+", ""))
                csw = int(parts[5].replace("+", ""))
                cpu_vals.append(cpu)
                idlew_vals.append(idlew)
                power_vals.append(power)
                csw_vals.append(csw)
            except ValueError:
                pass
                
    # Calculate CSW per second rate
    csw_rates = []
    if len(csw_vals) >= 2:
        for i in range(1, len(csw_vals)):
            csw_rates.append(csw_vals[i] - csw_vals[i-1])
            
    # Parse telemetry
    render_cb_vals = []
    presented_fps_vals = []
    cmd_buf_vals = []
    audio_cb_vals = []
    audio_frames_vals = []
    audio_cpu_vals = []
    
    for t_line in telemetry_snapshots:
        # e.g.: RenderCallbacks/s: 0 | PresentedFrames/s: 0 | CmdBuffers/s: 0 | AudioCallbacks/s: 94 | AudioFrames/s: 44100 | AudioCPUms/s: 0.002
        rc_m = re.search(r"RenderCallbacks/s:\s*(\d+)", t_line)
        pf_m = re.search(r"PresentedFrames/s:\s*(\d+)", t_line)
        cb_m = re.search(r"CmdBuffers/s:\s*(\d+)", t_line)
        ac_m = re.search(r"AudioCallbacks/s:\s*(\d+)", t_line)
        af_m = re.search(r"AudioFrames/s:\s*(\d+)", t_line)
        cpu_m = re.search(r"AudioCPUms/s:\s*([\d\.]+)", t_line)
        
        if rc_m: render_cb_vals.append(int(rc_m.group(1)))
        if pf_m: presented_fps_vals.append(int(pf_m.group(1)))
        if cb_m: cmd_buf_vals.append(int(cb_m.group(1)))
        if ac_m: audio_cb_vals.append(int(ac_m.group(1)))
        if af_m: audio_frames_vals.append(int(af_m.group(1)))
        if cpu_m: audio_cpu_vals.append(float(cpu_m.group(1)))
        
    avg_cpu = sum(cpu_vals) / len(cpu_vals) if cpu_vals else 0.0
    avg_idlew = sum(idlew_vals) / len(idlew_vals) if idlew_vals else 0.0
    avg_power = sum(power_vals) / len(power_vals) if power_vals else 0.0
    avg_csw_rate = sum(csw_rates) / len(csw_rates) if csw_rates else 0.0
    
    avg_rc = sum(render_cb_vals) / len(render_cb_vals) if render_cb_vals else 0.0
    avg_pf = sum(presented_fps_vals) / len(presented_fps_vals) if presented_fps_vals else 0.0
    avg_cb = sum(cmd_buf_vals) / len(cmd_buf_vals) if cmd_buf_vals else 0.0
    avg_ac = sum(audio_cb_vals) / len(audio_cb_vals) if audio_cb_vals else 0.0
    avg_af = sum(audio_frames_vals) / len(audio_frames_vals) if audio_frames_vals else 0.0
    avg_audio_cpu = sum(audio_cpu_vals) / len(audio_cpu_vals) if audio_cpu_vals else 0.0
    
    summary = {
        "name": name,
        "avg_cpu_percent": round(avg_cpu, 2),
        "avg_idle_wakeups_per_sec": round(avg_idlew, 1),
        "avg_power_score": round(avg_power, 2),
        "avg_context_switches_per_sec": round(avg_csw_rate, 1),
        "avg_render_callbacks_per_sec": round(avg_rc, 1),
        "avg_presented_frames_per_sec": round(avg_pf, 1),
        "avg_cmd_buffers_per_sec": round(avg_cb, 1),
        "avg_audio_callbacks_per_sec": round(avg_ac, 1),
        "avg_audio_frames_per_sec": round(avg_af, 1),
        "avg_audio_cpu_ms_per_sec": round(avg_audio_cpu, 4),
    }
    
    print(f"   📊 [SUMMARY]")
    print(f"      • CPU %:                  {summary['avg_cpu_percent']}%")
    print(f"      • Idle Wakeups / s:       {summary['avg_idle_wakeups_per_sec']}")
    print(f"      • Power Score (Energy):   {summary['avg_power_score']}")
    print(f"      • Context Switches / s:   {summary['avg_context_switches_per_sec']}")
    print(f"      • Render Callbacks / s:   {summary['avg_render_callbacks_per_sec']}")
    print(f"      • Presented FPS:          {summary['avg_presented_frames_per_sec']}")
    print(f"      • Command Buffers / s:    {summary['avg_cmd_buffers_per_sec']}")
    print(f"      • Audio Callbacks / s:    {summary['avg_audio_callbacks_per_sec']}")
    print(f"      • Audio Frames / s:       {summary['avg_audio_frames_per_sec']}")
    print(f"      • Audio CPU Time:         {summary['avg_audio_cpu_ms_per_sec']} ms/s")
    
    return summary

def main():
    print("=" * 80)
    print("🔋 SIRIEDGE CRITICAL BATTERY ENERGY INVESTIGATION & BENCHMARK")
    print("=" * 80)
    
    results = {}
    
    # Condition 1: AUTO + Battery + No Music (Idle Auto Profile) - 30s sustained measurement
    results["condition_a_auto_idle_battery"] = profile_condition(
        "Condition A: AUTO + Battery + No Music (Monitor ON)",
        ["--auto", "--battery-saver"],
        duration_sec=30,
        sample_interval=1
    )
    
    # Condition 2: FORCE OFF (Monitor Disabled for A/B comparison)
    results["condition_b_force_off"] = profile_condition(
        "Condition B: AUTO + Battery + Monitor Disabled (Force OFF)",
        ["--force-off"],
        duration_sec=15,
        sample_interval=1
    )
    
    # Condition 3: AUTO + AC Charger Connected (No Music)
    results["condition_c_auto_ac_no_music"] = profile_condition(
        "Condition C: AUTO + AC Charger + No Music",
        ["--auto"],
        duration_sec=15,
        sample_interval=1
    )
    
    # Condition 4: MANUAL ON (Glow Active, Battery Saver Profile)
    results["condition_d_manual_on_battery"] = profile_condition(
        "Condition D: MANUAL ON (Active Glow, Battery Profile)",
        ["--force-on", "--battery-saver"],
        duration_sec=15,
        sample_interval=1
    )
    
    # Condition 5: MANUAL ON (Active Glow, Max Performance Profile)
    results["condition_e_manual_on_ac"] = profile_condition(
        "Condition E: MANUAL ON (Active Glow, Max Performance Profile)",
        ["--force-on"],
        duration_sec=15,
        sample_interval=1
    )
    
    print("\n" + "=" * 80)
    print("📋 SUMMARY REPORT TABLE")
    print("=" * 80)
    print(f"{'Condition':<45} | {'CPU%':<6} | {'Wakeups':<8} | {'Power':<6} | {'CSW/s':<8} | {'FPS':<6} | {'CmdBuf/s':<8}")
    print("-" * 105)
    for k, v in results.items():
        print(f"{v['name']:<45} | {v['avg_cpu_percent']:<6} | {v['avg_idle_wakeups_per_sec']:<8} | {v['avg_power_score']:<6} | {v['avg_context_switches_per_sec']:<8} | {v['avg_presented_frames_per_sec']:<6} | {v['avg_cmd_buffers_per_sec']:<8}")
    print("=" * 105)
    
    with open("SiriEdge_Battery_Energy_Report.json", "w") as f:
        json.dump(results, f, indent=2)
    print("Saved report to SiriEdge_Battery_Energy_Report.json")

if __name__ == "__main__":
    main()
