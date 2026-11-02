echo "Converting to JED"
wine POF2JED.exe output_files/VideoULA.pof -device 1504as
if [ $? -ne 0 ]; then
  echo "JED conversion failed"
  exit 2
fi

echo "Removing asterisk"
awk '{if ((NR < 100) || !match($0,"^*.")) {print $0 }}' <output_files/VideoULA.jed >tmp.jed

if test -d prjbureau; then
  echo "Converting to SVF"
  cd prjbureau
  python3 -m util.fuseconv -d ATF1504AS  ../tmp.jed ../output_files/VideoULA.svf
  cd ..
else
  echo "prjbureau missing"
  exit 1
fi

rm -f tmp.jed
echo "Done"
echo
echo "Program chip using:"
echo "$ openocd -f interface/ft232r.cfg -c 'adapter speed 400' -c 'jtag newtap ATF1504AS tap -irlen 3 -expected-id 0x0150403f' -c init -c 'svf output_files/VideoULA.svf' -c 'sleep 200' -c shutdown"
