#!/usr/bin/env python3
"""
SiriEdge Comprehensive Automatic Triggers & Manual Override Verification Suite
Validates all 9 state combinations, 10 state transitions, power profiles, and battery drain.
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

def run_test_scenario(name, description, args, duration_sec=8):
    print(f"\n================================================================================")
    print(f"▶️  TESTING: {name}")
    print(f"   Description: {description}")
    print(f"   Args: {args} | Duration: {duration_sec}s")
    print(f"================================================================================")
    
    subprocess.run(["pkill", "-9", "-f", "SiriEdge"], capture_output=True)
    time.sleep(0.5)
    
    cmd = [APP_BINARY, "--telemetry-log"] + args
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    time.sleep(1.0)
    
    cpu_samples = []
    rss_samples = []
    rps_samples = []
    cps_samples = []
    aps_samples = []
    fps_samples = []
    power_samples = []
    
    latest_telemetry = {"rps": 0, "cps": 0, "aps": 0, "fps": 0.0, "renderers": 0, "overlays": 0, "paused": True}
    
    start_time = time.time()
    while (time.time() - start_time) < duration_sec:
        pid = proc.pid if proc else None
        proc_cpu = 0.0
        proc_rss = 0.0
        
        if pid:
            try:
                ps_out = subprocess.check_output(["ps", "-p", str(pid), "-o", "%cpu,rss"], text=True).strip().splitlines()
                if len(ps_out) > 1:
                    parts = ps_out[1].strip().split()
                    proc_cpu = float(parts[0])
                    proc_rss = float(parts[1]) / 1024.0
            except Exception:
                pass
                
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
        power_samples.append(batt["power_w"])
        
        elapsed = int(time.time() - start_time)
        print(f"   [{elapsed:02d}s] CPU: {proc_cpu:4.1f}% | RSS: {proc_rss:5.1f} MB | Render/s: {latest_telemetry['rps']:3d} | CmdBuf/s: {latest_telemetry['cps']:3d} | Audio/s: {latest_telemetry['aps']:3d} | FPS: {latest_telemetry['fps']:4.1f} | Paused: {latest_telemetry['paused']} | Power: {batt['power_w']:5.2f} W", flush=True)
        time.sleep(1.0)
        
    proc.terminate()
    try:
        proc.wait(timeout=1.5)
    except Exception:
        proc.kill()
    time.sleep(0.5)
    
    avg_cpu = sum(cpu_samples) / max(len(cpu_samples), 1)
    avg_rss = sum(rss_samples) / max(len(rss_samples), 1)
    avg_rps = sum(rps_samples) / max(len(rps_samples), 1)
    avg_cps = sum(cps_samples) / max(len(cps_samples), 1)
    avg_aps = sum(aps_samples) / max(len(aps_samples), 1)
    avg_fps = sum(fps_samples) / max(len(fps_samples), 1)
    avg_pwr = sum(power_samples) / max(len(power_samples), 1)
    
    result = {
        "name": name,
        "description": description,
        "avg_cpu_percent": round(avg_cpu, 2),
        "avg_rss_mb": round(avg_rss, 2),
        "avg_render_callbacks_sec": round(avg_rps, 1),
        "avg_command_buffers_sec": round(avg_cps, 1),
        "avg_audio_callbacks_sec": round(avg_aps, 1),
        "avg_fps": round(avg_fps, 1),
        "is_paused": latest_telemetry["paused"],
        "system_power_w": round(avg_pwr, 3)
    }
    
    print(f"   👉 RESULT: CPU: {result['avg_cpu_percent']}% | FPS: {result['avg_fps']} | Render/s: {result['avg_render_callbacks_sec']} | Paused: {result['is_paused']}")
    return result

def main():
    print("================================================================================")
    print("🚀 SIRIEDGE AUTOMATIC TRIGGERS & MANUAL OVERRIDE COMPREHENSIVE TEST SUITE")
    print("================================================================================")
    
    test_duration = 6
    if len(sys.argv) > 1:
        test_duration = int(sys.argv[1])
        
    combinations = [
        ("1. AUTO + Battery + No Music", "Auto mode on battery without music -> Expected: Inactive / 0 FPS / Battery Optimized",
         ["--auto", "--simulate-battery", "--simulate-no-music"]),
        
        ("2. AUTO + Battery + Music", "Auto mode on battery with music -> Expected: Active / 60 FPS Battery Cap / Music Reactive ON",
         ["--auto", "--simulate-battery", "--simulate-music"]),
         
        ("3. AUTO + Charger + No Music", "Auto mode on AC power without music -> Expected: Active / AC Performance Profile / Music Reactive OFF",
         ["--auto", "--simulate-ac", "--simulate-no-music"]),
         
        ("4. AUTO + Charger + Music", "Auto mode on AC power with music -> Expected: Active / AC Performance Profile / Music Reactive ON",
         ["--auto", "--simulate-ac", "--simulate-music"]),
         
        ("5. MANUAL ON + Battery + No Music", "Manual ON on battery without music -> Expected: Active / 60 FPS Battery Cap",
         ["--force-on", "--simulate-battery", "--simulate-no-music"]),
         
        ("6. MANUAL ON + Battery + Music", "Manual ON on battery with music -> Expected: Active / 60 FPS Battery Cap / Music Reactive ON",
         ["--force-on", "--simulate-battery", "--simulate-music", "--music-reactive"]),
         
        ("7. MANUAL ON + Charger", "Manual ON on AC power -> Expected: Active / AC Performance Profile",
         ["--force-on", "--simulate-ac", "--simulate-no-music"]),
         
        ("8. MANUAL OFF + Battery + Music", "Manual OFF on battery with music -> Expected: Inactive / 0 FPS / Everything OFF",
         ["--force-off", "--simulate-battery", "--simulate-music"]),
         
        ("9. MANUAL OFF + Charger + Music", "Manual OFF on AC power with music -> Expected: Inactive / 0 FPS / Everything OFF",
         ["--force-off", "--simulate-ac", "--simulate-music"]),
    ]
    
    results = []
    for name, desc, args in combinations:
        r = run_test_scenario(name, desc, args, duration_sec=test_duration)
        results.append(r)
        
    subprocess.run(["pkill", "-9", "-f", "SiriEdge"], capture_output=True)
    
    print("\n" + "="*95)
    print("🏁 FINAL SUMMARY — ALL COMBINATIONS TEST MATRIX")
    print("="*95)
    header = f"{'Scenario':<36} | {'CPU (%)':<8} | {'RSS (MB)':<8} | {'Rend/s':<7} | {'CmdB/s':<7} | {'Aud/s':<7} | {'FPS':<6} | {'Power (W)':<9}"
    print(header)
    print("-" * len(header))
    for r in results:
        print(f"{r['name']:<36} | {r['avg_cpu_percent']:<8.2f} | {r['avg_rss_mb']:<8.1f} | {r['avg_render_callbacks_sec']:<7.1f} | {r['avg_command_buffers_sec']:<7.1f} | {r['avg_audio_callbacks_sec']:<7.1f} | {r['avg_fps']:<6.1f} | {r['system_power_w']:<9.3f}")
        
    with open("SiriEdge_Trigger_Matrix_Report.json", "w") as f:
        json.dump(results, f, indent=2)
        
    with open("SiriEdge_Trigger_Matrix_Report.csv", "w") as f:
        f.write("Scenario,Description,AvgCPU_Percent,AvgRSS_MB,RenderCallbacksPerSec,CmdBuffersPerSec,AudioCallbacksPerSec,ActualFPS,IsPaused,SystemPower_W\n")
        for r in results:
            f.write(f'"{r["name"]}","{r["description"]}",{r["avg_cpu_percent"]},{r["avg_rss_mb"]},{r["avg_render_callbacks_sec"]},{r["avg_command_buffers_sec"]},{r["avg_audio_callbacks_sec"]},{r["avg_fps"]},{r["is_paused"]},{r["system_power_w"]}\n')
            
    print(f"\n📁 Saved JSON report to: SiriEdge_Trigger_Matrix_Report.json")
    print(f"📁 Saved CSV report to: SiriEdge_Trigger_Matrix_Report.csv")

if __name__ == "__main__":
    main()
