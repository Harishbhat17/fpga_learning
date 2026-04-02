## timing_closure_flow.tcl
## Quartus Prime end-to-end timing closure automation
## Usage: quartus_sh --script=timing_closure_flow.tcl

# ============================================================
# Configuration
# ============================================================
set PROJECT_NAME  "my_design"
set TOP_MODULE    "top"
set REPORTS_DIR   "./reports"
set WNS_THRESHOLD  0.050  ;# Fail if WNS < this value (ns)

# ============================================================
# Helper Procedures
# ============================================================
proc log {msg} {
    puts "\n[string repeat = 60]\n$msg\n[string repeat = 60]"
}

proc run_sta_and_report {rpt_dir} {
    package require ::quartus::timing_check

    read_netlist
    read_sdc  constraints/top.sdc

    create_timing_netlist
    update_timing_netlist

    file mkdir $rpt_dir

    report_timing_summary  -file "${rpt_dir}/timing_summary.rpt"
    report_fmax_summary    -file "${rpt_dir}/fmax_summary.rpt"
    report_timing -setup -npaths 20 -detail full_path \
                  -file "${rpt_dir}/worst_setup.rpt"
    report_timing -hold  -npaths 20 -detail full_path \
                  -file "${rpt_dir}/worst_hold.rpt"
    report_cdc             -file "${rpt_dir}/cdc.rpt"
    report_exceptions -all -file "${rpt_dir}/exceptions.rpt"

    # Return WNS
    return [get_timing_analysis_summary_results -setup]
}

# ============================================================
# 1. Open Project
# ============================================================
log "Opening project: $PROJECT_NAME"
package require ::quartus::project
package require ::quartus::flow

project_open $PROJECT_NAME

# ============================================================
# 2. Synthesis
# ============================================================
log "Running Analysis & Synthesis"
execute_module -tool MAP

# ============================================================
# 3. Fitter (Place & Route)
# ============================================================
log "Running Fitter"
execute_module -tool FIT

# ============================================================
# 4. Timing Analysis
# ============================================================
log "Running TimeQuest Timing Analysis"
execute_module -tool STA

# ============================================================
# 5. Collect Reports and Check
# ============================================================
log "Collecting timing reports"
file mkdir $REPORTS_DIR

set wns [run_sta_and_report $REPORTS_DIR]
puts "WNS = $wns ns (threshold = $WNS_THRESHOLD ns)"

if {$wns < $WNS_THRESHOLD} {
    log "TIMING NOT CLOSED — WNS = $wns ns"
    puts "Review reports in $REPORTS_DIR"
    puts "Consider: different seed, enable retiming, or RTL changes"

    # Try a second seed automatically
    log "Attempting alternate seed (seed=2)"
    set_global_assignment -name SEED 2
    execute_module -tool FIT
    execute_module -tool STA

    set wns2 [run_sta_and_report "${REPORTS_DIR}/seed2"]
    puts "Seed 2 WNS = $wns2 ns"

    if {$wns2 > $wns} {
        puts "Seed 2 is better — saving as primary result"
        file copy -force ${REPORTS_DIR}/seed2/timing_summary.rpt \
                         ${REPORTS_DIR}/timing_summary_best.rpt
    }
} else {
    log "TIMING CLOSURE ACHIEVED — WNS = $wns ns"

    # Generate bitstream
    log "Running Assembler (generating .sof)"
    execute_module -tool ASM

    puts "DONE — .sof file generated"
}

project_close
