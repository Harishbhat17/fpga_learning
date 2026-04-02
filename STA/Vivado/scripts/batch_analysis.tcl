## batch_analysis.tcl
## Analyze timing across multiple checkpoints (post-synth, post-place, post-route)
## and generate a comparative summary.
## Usage: vivado -mode batch -source batch_analysis.tcl

# ============================================================
# Configuration
# ============================================================
set CKPT_DIR    "./checkpoints"
set REPORTS_DIR "./batch_reports"
set WNS_TARGET   0.050

# List of checkpoints to analyze: {label filename}
set checkpoints {
    {post_synth   post_synth.dcp}
    {post_place   post_place.dcp}
    {post_route   post_route.dcp}
}

# ============================================================
# Helpers
# ============================================================
proc get_wns {} {
    set paths [get_timing_paths -setup -max_paths 1 -nworst 1 -quiet]
    if {[llength $paths] == 0} { return "N/A" }
    return [get_property SLACK $paths]
}

proc get_whs {} {
    set paths [get_timing_paths -hold -max_paths 1 -nworst 1 -quiet]
    if {[llength $paths] == 0} { return "N/A" }
    return [get_property SLACK $paths]
}

proc get_tns {} {
    set total 0.0
    foreach p [get_timing_paths -setup -max_paths 10000 -quiet] {
        set s [get_property SLACK $p]
        if {$s < 0} { set total [expr {$total + $s}] }
    }
    return $total
}

# ============================================================
# Main analysis loop
# ============================================================
file mkdir $REPORTS_DIR

set summary_file [open "${REPORTS_DIR}/comparative_summary.txt" w]
puts $summary_file [format "%-20s %10s %10s %10s %s" \
    "Checkpoint" "WNS(ns)" "WHS(ns)" "TNS(ns)" "Status"]
puts $summary_file [string repeat "-" 70]

foreach ckpt_entry $checkpoints {
    set label    [lindex $ckpt_entry 0]
    set filename [lindex $ckpt_entry 1]
    set ckpt_path "${CKPT_DIR}/${filename}"

    if {![file exists $ckpt_path]} {
        puts "SKIP: $ckpt_path not found"
        continue
    }

    puts "\n>>> Analyzing: $label ($ckpt_path)"
    open_checkpoint $ckpt_path

    # Run basic timing analysis
    set wns [get_wns]
    set whs [get_whs]
    set tns [get_tns]

    # Determine status
    if {$wns eq "N/A"} {
        set status "NO_CONSTRAINTS"
    } elseif {$wns >= $WNS_TARGET && $whs >= 0} {
        set status "PASS"
    } elseif {$whs < 0} {
        set status "HOLD_FAIL"
    } else {
        set status "SETUP_FAIL"
    }

    puts $summary_file [format "%-20s %10.3f %10.3f %10.3f %s" \
        $label $wns $whs $tns $status]

    # Per-checkpoint detailed reports
    set rdir "${REPORTS_DIR}/${label}"
    file mkdir $rdir
    report_timing_summary -file "${rdir}/timing_summary.rpt"
    report_timing -setup -nworst 10 -path_type full_clock_expanded \
                  -file "${rdir}/worst_setup.rpt"
    report_timing -hold  -nworst 10 -file "${rdir}/worst_hold.rpt"
    report_cdc    -details -file "${rdir}/cdc.rpt"

    close_design
}

close $summary_file

puts "\nBatch analysis complete. Results in: $REPORTS_DIR"
puts "Summary:"
set f [open "${REPORTS_DIR}/comparative_summary.txt" r]
puts [read $f]
close $f
