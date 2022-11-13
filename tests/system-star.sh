# GNU Shepherd --- Test whether 'system*' is blocking.
# Copyright © 2022 Ludovic Courtès <ludo@gnu.org>
#
# This file is part of the GNU Shepherd.
#
# The GNU Shepherd is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at
# your option) any later version.
#
# The GNU Shepherd is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the GNU Shepherd.  If not, see <http://www.gnu.org/licenses/>.

shepherd --version
herd --version

socket="t-socket-$$"
conf="t-conf-$$"
log="t-log-$$"
stamp="t-stamp-$$"
pid="t-pid-$$"

herd="herd -s $socket"

trap "cat $log || true; rm -f $socket $conf $stamp $log;
      test -f $pid && kill \`cat $pid\` || true; rm -f $pid" EXIT

script="while [ ! -f $PWD/$stamp ] ; do sleep 0.1 ; done ; exit \$(cat $PWD/$stamp)"

cat > "$conf" <<EOF
(register-services
 (make <service>
   #:provides '(test)
   #:start (lambda _
             (list 'exit-code
                   (status:exit-val
                    (system* "$SHELL" "-c" "$script"))))
   #:stop  (lambda _
             (delete-file "$stamp"))
   #:respawn? #f))
EOF

rm -f "$pid"
shepherd -I -s "$socket" -c "$conf" -l "$log" --pid="$pid" &

# Wait till it's ready.
while ! test -f "$pid" ; do sleep 0.3 ; done

shepherd_pid="`cat $pid`"

kill -0 $shepherd_pid

# 'herd start' will block until the script exits...
$herd start test &

# ... so at this point the service is stopped.
$herd status test | grep "stopped"

# Touch $stamp.  The shell script passed to 'system*' should complete shortly
# after that.
echo 123 > "$stamp"

n=0
while [ $n -lt 20 ]
do
    if $herd status test | grep "started"
    then
	break
    else
	n=$(expr $n + 1)
	sleep 1
    fi
done
$herd status test | grep "started"
$herd status test | grep "exit-code 123"

$herd stop test
! test -f "$stamp"

$herd stop root