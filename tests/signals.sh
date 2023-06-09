# GNU Shepherd --- Make sure SIGINT, SIGTERM, and SIGHUP are correctly handled.
# Copyright © 2014, 2016, 2023 Ludovic Courtès <ludo@gnu.org>
# Copyright © 2018 Carlo Zancanaro <carlo@zancanaro.id.au>
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

trap "rm -f $socket $conf $stamp $log;
      test -f $pid && kill \`cat $pid\` || true; rm -f $pid" EXIT

cat > "$conf"<<EOF
(use-modules (srfi srfi-26))
(register-services
 (list (service
	 '(test)
	 #:start (const #t)
	 #:stop  (lambda _
		   (call-with-output-file "$stamp"
		     (lambda (port)
		       (display "stopped" port))))
	 #:respawn? #f)))
(start-service (lookup-service 'test))
EOF

for signal in INT TERM HUP; do

  rm -f "$pid" "$stamp" "$socket"
  shepherd -I -s "$socket" -c "$conf" --pid="$pid" --log="$log" &

  while [ ! -f "$pid" ] ; do sleep 0.5 ; done

  # Send signal to shepherd.
  kill -$signal "`cat "$pid"`"
  while kill -0 "`cat "$pid"`" ; do sleep 0.5 ; done

  # Make sure the service's 'stop' method was called.
  test -f "$stamp"

done
