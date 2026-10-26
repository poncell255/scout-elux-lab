cd /root/pkgs/teams/enxuto/teams-for-linux
find . -type f | while read f; do readelf -d "$f" 2>/dev/null | grep -q 'NEEDED.*\[libc\.so\]' && { echo "$f"; file "$f" | cut -c1-200; }; done
