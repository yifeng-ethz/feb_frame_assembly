package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. toolkits infra cmsis_svd lib mu3e_cmsis_svd.tcl]]
source $helper_file

namespace eval ::mu3e::cmsis::spec {}

proc ::mu3e::cmsis::spec::build_device {} {
    return [::mu3e::cmsis::svd::device MU3E_FEB_FRAME_ASSEMBLY \
        -version 26.0.328 \
        -description "CMSIS-SVD description of the feb_frame_assembly CSR window. This conservative first-pass schema exposes the 16-word relative aperture as read-only WORD registers until the IP author publishes the exact control/status fields intended for software." \
        -peripherals [list \
            [::mu3e::cmsis::svd::peripheral FEB_FRAME_ASSEMBLY_CSR 0x0 \
                -description "Relative 16-word CSR aperture for FEB frame assembly." \
                -groupName MU3E_DATA_PATH \
                -addressBlockSize 0x40 \
                -registers [::mu3e::cmsis::svd::word_window_registers 16 \
                    -descriptionPrefix "FEB frame assembly CSR word" \
                    -fieldDescriptionPrefix "Raw FEB frame assembly CSR word" \
                    -access read-only]]]]
}

if {[info exists ::argv0] &&
    [file normalize $::argv0] eq [file normalize [info script]]} {
    set out_path [file join $script_dir feb_frame_assembly.svd]
    if {[llength $::argv] >= 1} {
        set out_path [lindex $::argv 0]
    }
    ::mu3e::cmsis::svd::write_device_file \
        [::mu3e::cmsis::spec::build_device] $out_path
}
