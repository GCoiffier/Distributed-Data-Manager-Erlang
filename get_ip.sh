ifconfig | awk -F ":"  '/inet adr/{split($2,a," ");print a[1]}' | tail -1
