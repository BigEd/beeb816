# beeb816
65816 upgrade for BBC Micro, including lots of fast RAM



rtl           -       original level1b RTL
emu6502_rtl   -       stripped back 6502 emulation only, trialling clock delays for CPU vs BBC
trial_rtl     -       extension of above to allow access to high memory in 816 mode only
trial2_rtl    -       extension of above to allow ROM/RAM remapping, but no clock switching
trial3_rtl    -       full functionality with synchronous CPU clock/async BBC clock switch
trial4_rtl    -       full functionality with async CPU and BBC clock switches
trial5_rtl    -       full functionality with async CPU and BBC clock switches, force all mapping/selection to occur in PHI1/switch in PHI1
trial6_rtl    -       full functionality with synchronous CPU clock/async BBC clock switch, force all mapping/selection to occur in PHI1/switch in PHI1
