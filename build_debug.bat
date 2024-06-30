@echo off

odin build . -debug -build-mode:dll -out:odin_clap_plugin.clap
del "C:\Users\corey\Documents\OdinStuff\odin_clap_plugin\odin_clap_plugin.exp"
del "C:\Users\corey\Documents\OdinStuff\odin_clap_plugin\odin_clap_plugin.lib"

pause