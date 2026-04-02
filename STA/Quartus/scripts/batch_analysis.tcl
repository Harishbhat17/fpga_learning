## batch_analysis.tcl
## Analyze timing across multiple Quartus compilation seeds to find the best result
## Usage: quartus_sh --script=batch_analysis.tcl

# ============================================================
# Configuration
# ============================================================
set PROJECT_NAME  "my_design"
set REPORTS_DIR   "./batch_reports"
set SEEDS         {1 2 3 4 5}

# ============================================================
# Helpers
# ============================================================
proc get_wns_from_sta {} {
    package require ::quartus::timing_check
    read_netlist
    create_timing_netlist
    update_timing_netlist
    return [get_timing_analysis_summary_results -setup]
}

proc get_whs_from_sta {} {
    package require ::quartus::timing_check
    return [get_timing_analysis_summary_results -hold]
}

# ============================================================
# Main
# ============================================================
file mkdir $REPORTS_DIR

package require ::quartus::project
package require ::quartus::flow

project_open $PROJECT_NAME

# Initial synthesis (only once — same for all seeds)
execute_module -tool MAP

set best_seed  1
set best_wns  -999.0
set results    {}

set summary_fh [open "${REPORTS_DIR}/seed_sweep_summary.txt" w]
puts $summary_fh [format "%-6s %10s %10s %s" "Seed" "WNS(ns)" "WHS(ns)" "Status"]
puts $summary_fh [string repeat - 40]

foreach seed $SEEDS {
    puts "\n>>> Running seed $seed"
    set_global_assignment -name SEED $seed

    execute_module -tool FIT
    execute_module -tool STA

    read_sdc constraints/top.sdc
    set wns [get_wns_from_sta]
    set whs [get_whs_from_sta]

    if {$wns >= 0 && $whs >= 0} {
        set status "PASS"
    } elseif {$whs < 0} {
        set status "HOLD_FAIL"
    } else {
        set status "SETUP_FAIL(${wns}ns)"
    }

    puts $summary_fh [format "%-6s %10.3f %10.3f %s" $seed $wns $whs $status]

    # Save per-seed reports
    set rdir "${REPORTS_DIR}/seed_${seed}"
    file mkdir $rdir
    report_timing_summary -file "${rdir}/timing_summary.rpt"
    report_timing -setup -npaths 10 -detail full_path \
                  -file "${rdir}/worst_setup.rpt"

    if {$wns > $best_wns} {
        set best_wns  $wns
        set best_seed $seed
    }
}

close $summary_fh

puts "\n[string repeat = 40]"
puts "BEST RESULT: Seed $best_seed with WNS = $best_wns ns"
puts "[string repeat = 40]"

# If best seed is not the current seed, re-run fitter with best seed
if {$best_seed != [lindex $SEEDS end]} {
    set_global_assignment -name SEED $best_seed
    execute_module -tool FIT
    execute_module -tool ASM
    puts "Re-compiled with best seed $best_seed and generated bitstream."
}

project_close
