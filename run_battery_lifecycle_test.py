#!/usr/bin/env python3
"""
SiriEdge Controlled Battery & Lifecycle Telemetry Benchmark
Executes 6 controlled scenarios:
A. SiriEdge completely terminated
B. SiriEdge running, overlay active (60 FPS)
C. SiriEdge running, overlay hidden
D. SiriEdge running, Music Reactive OFF
E. SiriEdge running, Music Reactive ON
F. SiriEdge Battery Saver 30 FPS
"""

import os
import sys
import time
import subprocess
import re
import json

APP_BINARY = "./SiriEdge.app/Contents/MacOS/SiriEdge"

def get_battery_telemetry():
    """Reads hardware battery voltage, current, and wattage from AppleSmartBattery."""
    try:
        output = subprocess.check_output(["ioreg", "-r", "-c", "AppleSmartBattery"], text=True)
        
        voltage_match = re.search(r'"Voltage"\s*=\s*(\d+)', output)
        amperage_match = re.search(r'"InstantAmperage"\s*=\s*(-?\d+)', output)
        power_match = re.search(r'"BatteryPower"\s*=\s*(\d+)', output)
        sys_power_match = re.search(r'"SystemLoad"\s*=\s*(\d+)', output)
        charging_match = re.search(r'"IsCharging"\s*=\s*(Yes|No|\d+)', output)
        
        voltage_mv = float(voltage_match.group(1)) if voltage_match else 12300.0
        voltage_v = voltage_mv / 1000.0
        
        amperage_ma = float(amperage_match.group(1)) if amperage_match else 0.0
        
        # System wattage calculation
        if sys_power_match and float(sys_power_match.group(1)) > 0:
            power_w = float(sys_power_match.group(1)) / 1000.0
        elif power_match and float(power_match.group(1)) > 0:
            power_w = float(power_match.group(1)) / 1000.0
        else:
            power_w = abs(amperage_ma * voltage_v) / 1000.0
            
        return {
            "voltage_v": voltage_v,
            "current_ma": amperage_ma,
            "power_w": power_w,
            "is_charging": charging_match.group(1) if charging_match else "Unknown"
        }
    except Exception as e:
        return {"voltage_v": 12.0, "current_ma": 0.0, "power_w": 0.0, "error": str(e)}

def parse_telemetry_line(line):
    """Parses [SiriEdge Telemetry] output line."""
    m_rps = re.search(r'RenderCallbacks/s:\s*(\d+)', line)
    m_cps = re.search(r'CmdBuffers/s:\s*(\d+)', line)
    m_aps = re.search(r'AudioCallbacks/s:\s*(\d+)', line)
    m_fps = re.search(r'ActualFPS:\s*([\d\.]+)', line)
    m_ren = re.search(r'ActiveRenderers:\s*(\d+)', line)
    m_ovl = re.search(r'ActiveOverlays:\s*(\d+)', line)
    m_pau = re.search(r'IsPaused:\s*(true|false)', line)
    
    return {
        "rps": int(m_rps.group(1)) if m_rps else 0,
        "cps": int(m_cps.group(1)) if m_cps else 0,
        "aps": int(m_aps.group(1)) if m_aps else 0,
        "fps": float(m_fps.group(1)) if m_fps else 0.0,
        "renderers": int(m_ren.group(1)) if m_ren else 0,
        "overlays": int(m_ovl.group(1)) if m_ovl else 0,
        "paused": (m_pau.group(1) == 'true') if m_pau else False
    }

def run_scenario(name, description, args, duration_sec=15):
    print(f"\n========================================================")
    print(f"▶️ RUNNING SCENARIO: {name} ({description})")
    print(f"   Duration: {duration_sec}s | Args: {args}")
    print(f"========================================================")
    
    # Kill any existing SiriEdge instances
    subprocess.run(["pkill", "-9", "-f", "SiriEdge"], capture_output=True)
    time.sleep(1.0)
    
    proc = None
    if args is not None:
        cmd = [APP_BINARY, "--telemetry-log"] + args
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        time.sleep(1.5)
    
    cpu_samples = []
    rss_samples = []
    rps_samples = []
    cps_samples = []
    aps_samples = []
    fps_samples = []
    voltage_samples = []
    current_samples = []
    power_samples = []
    
    latest_telemetry = {"rps": 0, "cps": 0, "aps": 0, "fps": 0.0, "renderers": 0, "overlays": 0, "paused": True}
    
    start_time = time.time()
    while (time.time() - start_time) < duration_sec:
        # Check process state
        pid = proc.pid if proc else None
        proc_cpu = 0.0
        proc_rss = 0.0
        
        if pid:
            try:
                ps_out = subprocess.check_output(["ps", "-p", str(pid), "-o", "%cpu,rss"], text=True).strip().splitlines()
                if len(ps_out) > 1:
                    parts = ps_out[1].strip().split()
                    proc_cpu = float(parts[0])
                    proc_rss = float(parts[1]) / 1024.0 # Convert KB to MB
            except Exception:
                pass
                
        # Read process stdout for telemetry lines if available (non-blocking)
        if proc:
            import select
            while True:
                r, _, _ = select.select([proc.stdout], [], [], 0.05)
                if not r:
                    break
                line = proc.stdout.readline()
                if not line:
                    break
                if "[SiriEdge Telemetry]" in line:
                    latest_telemetry = parse_telemetry_line(line)
        
        batt = get_battery_telemetry()
        
        cpu_samples.append(proc_cpu)
        rss_samples.append(proc_rss)
        rps_samples.append(latest_telemetry["rps"])
        cps_samples.append(latest_telemetry["cps"])
        aps_samples.append(latest_telemetry["aps"])
        fps_samples.append(latest_telemetry["fps"])
        voltage_samples.append(batt["voltage_v"])
        current_samples.append(batt["current_ma"])
        power_samples.append(batt["power_w"])
        
        elapsed = int(time.time() - start_time)
        print(f"   [{elapsed:02d}s] CPU: {proc_cpu:4.1f}% | RSS: {proc_rss:5.1f} MB | Render/s: {latest_telemetry['rps']:3d} | CmdBuf/s: {latest_telemetry['cps']:3d} | Audio/s: {latest_telemetry['aps']:3d} | FPS: {latest_telemetry['fps']:4.1f} | Paused: {latest_telemetry['paused']} | Power: {batt['power_w']:5.2f} W", flush=True)
        time.sleep(1.0)
        
    if proc:
        proc.terminate()
        try:
            proc.wait(timeout=2.0)
        except Exception:
            proc.kill()
    time.sleep(1.0)
    
    avg_cpu = sum(cpu_samples) / max(len(cpu_samples), 1)
    avg_rss = sum(rss_samples) / max(len(rss_samples), 1)
    avg_rps = sum(rps_samples) / max(len(rps_samples), 1)
    avg_cps = sum(cps_samples) / max(len(cps_samples), 1)
    avg_aps = sum(aps_samples) / max(len(aps_samples), 1)
    avg_fps = sum(fps_samples) / max(len(fps_samples), 1)
    avg_vol = sum(voltage_samples) / max(len(voltage_samples), 1)
    avg_cur = sum(current_samples) / max(len(current_samples), 1)
    avg_pwr = sum(power_samples) / max(len(power_samples), 1)
    
    result = {
        "name": name,
        "description": description,
        "avg_cpu_percent": round(avg_cpu, 2),
        "peak_cpu_percent": round(max(cpu_samples) if cpu_samples else 0.0, 2),
        "avg_rss_mb": round(avg_rss, 2),
        "avg_render_callbacks_sec": round(avg_rps, 1),
        "avg_command_buffers_sec": round(avg_cps, 1),
        "avg_audio_callbacks_sec": round(avg_aps, 1),
        "avg_fps": round(avg_fps, 1),
        "battery_voltage_v": round(avg_vol, 3),
        "battery_current_ma": round(avg_cur, 1),
        "system_power_w": round(avg_pwr, 3)
    }
    
    print(f"📊 SUMMARY for {name}:")
    print(f"   • Avg CPU: {result['avg_cpu_percent']}% (Peak: {result['peak_cpu_percent']}%)")
    print(f"   • Avg RSS: {result['avg_rss_mb']} MB")
    print(f"   • Render Callbacks/sec: {result['avg_render_callbacks_sec']}")
    print(f"   • Command Buffers/sec: {result['avg_command_buffers_sec']}")
    print(f"   • Audio Callbacks/sec: {result['avg_audio_callbacks_sec']}")
    print(f"   • Measured FPS: {result['avg_fps']}")
    print(f"   • System Power: {result['system_power_w']} W ({result['battery_current_ma']} mA @ {result['battery_voltage_v']} V)")
    
    return result

def main():
    print("🚀 Starting SiriEdge Controlled Lifecycle & Battery Investigation Suite...")
    
    scenarios = [
        ("A_Terminated", "SiriEdge completely terminated (Baseline)", None),
        ("B_Active_60FPS", "SiriEdge running, overlay active (60 FPS default)", ["--active", "--no-music-reactive"]),
        ("C_Hidden_Inactive", "SiriEdge running, overlay hidden / inactive", ["--hidden", "--no-music-reactive"]),
        ("D_Active_Music_OFF", "SiriEdge running, Music Reactive OFF", ["--active", "--no-music-reactive"]),
        ("E_Active_Music_ON", "SiriEdge running, Music Reactive ON", ["--active", "--music-reactive"]),
        ("F_Battery_Saver_30FPS", "SiriEdge running, Battery Saver 30 FPS", ["--active", "--battery-saver", "--no-music-reactive"])
    ]
    
    duration = 20 # 20 seconds per scenario for high precision validation
    if len(sys.argv) > 1:
        duration = int(sys.argv[1])
        
    results = []
    for name, desc, args in scenarios:
        res = run_scenario(name, desc, args, duration_sec=duration)
        results.append(res)
        
    # Final cleanup
    subprocess.run(["pkill", "-9", "-f", "SiriEdge"], capture_output=True)
    
    print("\n" + "="*80)
    print("🏁 CONTROLLED LIFECYCLE & BATTERY BENCHMARK RESULTS")
    print("="*80)
    
    header = f"{'Scenario':<25} | {'CPU (%)':<8} | {'RSS (MB)':<8} | {'Rend/s':<7} | {'CmdB/s':<7} | {'Aud/s':<7} | {'FPS':<6} | {'Power (W)':<9}"
    print(header)
    print("-" * len(header))
    for r in results:
        print(f"{r['name']:<25} | {r['avg_cpu_percent']:<8.2f} | {r['avg_rss_mb']:<8.1f} | {r['avg_render_callbacks_sec']:<7.1f} | {r['avg_command_buffers_sec']:<7.1f} | {r['avg_audio_callbacks_sec']:<7.1f} | {r['avg_fps']:<6.1f} | {r['system_power_w']:<9.3f}")
        
    with open("SiriEdge_Lifecycle_Battery_Results.json", "w") as f:
        json.dump(results, f, indent=2)
        
    print(f"\n📁 Saved results to SiriEdge_Lifecycle_Battery_Results.json")

if __name__ == "__main__":
    main()
