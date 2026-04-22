transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+ila_data_out  -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.ila_data_out xil_defaultlib.glbl

do {ila_data_out.udo}

run 1000ns

endsim

quit -force
