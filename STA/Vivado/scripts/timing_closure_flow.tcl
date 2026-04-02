## timing_closure_flow.tcl
## Vivado end-to-end timing closure automation script
## Usage: vivado -mode batch -source timing_closure_flow.tcl
##        or source from Vivado TCL console after project is open

# ============================================================
# Configuration — edit these for your project
# ============================================================
set PROJECT_DIR  "./my_project"
set PROJECT_NAME "my_design"
set TOP_MODULE   "top"
set PART         "xczu7ev-ffvc1156-2-e"
set REPORTS_DIR  "./reports"
set CKPT_DIR     "./checkpoints"
set NUM_JOBS     8

# Target WNS threshold — fail if below this (ns)
# Set to 0.0 for exact closure, positive for margin
set WNS_THRESHOLD 0.050

# ============================================================
# Helper procedures
# ============================================================
proc log {msg} {
    puts "\n[string repeat = 60]\n$msg\n[string repeat = 60]"
}

proc check_wns {threshold label} {
    set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]
    if {$wns < $threshold} {
        puts "WARNING: $label WNS = $wns ns (threshold = $threshold ns)"
        return 0
    }
    puts "OK: $label WNS = $wns ns"
    return 1
}

proc save_reports {stage dir} {
    file mkdir $dir
    report_timing_summary          -file ${dir}/timing_summary_${stage}.rpt
    report_timing -setup -nworst 20 -path_type full_clock_expanded \
                  -file ${dir}/setup_paths_${stage}.rpt
    report_timing -hold  -nworst 20 -path_type full \
                  -file ${dir}/hold_paths_${stage}.rpt
    report_utilization -hierarchical \
                  -file ${dir}/utilization_${stage}.rpt
    report_clock_interaction -delay_type min_max \
                  -file ${dir}/clock_interaction_${stage}.rpt
    report_cdc    -details \
                  -file ${dir}/cdc_${stage}.rpt
    report_drc    -file ${dir}/drc_${stage}.rpt
}

# ============================================================
# 0. Setup directories
# ============================================================
file mkdir $REPORTS_DIR
file mkdir $CKPT_DIR

# ============================================================
# 1. Open the project
# ============================================================
log "Opening project: $PROJECT_NAME"
open_project ${PROJECT_DIR}/${PROJECT_NAME}.xpr

# ============================================================
# 2. Run Synthesis
# ============================================================
log "Running Synthesis"
reset_run synth_1
set_property strategy "Flow_PerfOptimized_high" [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
launch_runs synth_1 -jobs $NUM_JOBS
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis FAILED. Check synthesis logs."
}
log "Synthesis COMPLETE"

# Save synthesis checkpoint
open_run synth_1 -name netlist_1
write_checkpoint -force ${CKPT_DIR}/post_synth.dcp

# ============================================================
# 3. Run Implementation
# ============================================================
log "Running Implementation"
reset_run impl_1
set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED              true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED   true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE           AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

launch_runs impl_1 -jobs $NUM_JOBS
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation FAILED. Check implementation logs."
}
log "Implementation COMPLETE"

# ============================================================
# 4. Open routed checkpoint and generate reports
# ============================================================
log "Generating timing reports"
open_checkpoint ${CKPT_DIR}/post_route.dcp

# Also write the routed checkpoint for incremental flows
write_checkpoint -force ${CKPT_DIR}/post_route.dcp

save_reports "post_route" $REPORTS_DIR

# ============================================================
# 5. Check WNS/WHS
# ============================================================
log "Checking timing closure"

set timing_ok 1

# Setup check
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]
puts "WNS (setup) = $wns ns"
if {$wns < $WNS_THRESHOLD} {
    puts "FAIL: Setup timing not met! WNS = $wns ns < threshold $WNS_THRESHOLD ns"
    set timing_ok 0
}

# Hold check
set whs [get_property SLACK [get_timing_paths -hold -max_paths 1 -nworst 1]]
puts "WHS (hold) = $whs ns"
if {$whs < 0.0} {
    puts "FAIL: Hold timing not met! WHS = $whs ns"
    set timing_ok 0
}

if {$timing_ok} {
    log "TIMING CLOSURE ACHIEVED — WNS = $wns ns, WHS = $whs ns"
} else {
    log "TIMING NOT CLOSED — review reports in $REPORTS_DIR"
    # Optionally run post-route physical optimization to attempt hold fix
    phys_opt_design -hold_fix -directive AggressiveExplore
    write_checkpoint -force ${CKPT_DIR}/post_route_physopt2.dcp
    save_reports "post_physopt2" $REPORTS_DIR
}

# ============================================================
# 6. Generate bitstream only if timing is closed
# ============================================================
if {$timing_ok} {
    log "Writing bitstream"
    write_bitstream -force ${PROJECT_DIR}/${PROJECT_NAME}.bit
    log "DONE — Bitstream written to ${PROJECT_DIR}/${PROJECT_NAME}.bit"
} else {
    puts "Bitstream NOT generated — timing closure required first."
}
