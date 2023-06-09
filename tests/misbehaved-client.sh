# GNU Shepherd --- Make sure shepherd tolerates misbehaved clients.
# Copyright © 2016, 2018, 2022 Ludovic Courtès <ludo@gnu.org>
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
pid="t-pid-$$"

herd="herd -s $socket"

trap "rm -f $socket $conf $stamp $log;
      test -f $pid && kill \`cat $pid\` || true; rm -f $pid" EXIT

rm -f "$pid"
shepherd -I -s "$socket" -c /dev/null -l "$log" --pid="$pid" &

# Wait till it's ready.
while ! test -f "$pid" ; do sleep 0.3 ; done

shepherd_pid="`cat $pid`"

"$GUILE" -c "
(use-modules (shepherd comm))

;; Close without even talking.
(close-port (open-connection \"$socket\"))"

$herd status			# still here?

"$GUILE" -c "
(use-modules (shepherd comm))

;; Send an unbalanced sexp, then quit.
(let ((sock (open-connection \"$socket\")))
  (display \"(ah ha!\" sock)
  (close-port sock))"

$herd status			# still here?

"$GUILE" -c "
(use-modules (shepherd comm))

;; Send an unrecognized sexp.
(let ((sock (open-connection \"$socket\")))
  (display \"(hi there)\" sock))"

$herd status			# still here?

"$GUILE" -c "
(use-modules (shepherd comm) (shepherd support))

(let ((sock (open-connection \"$socket\")))
  (setvbuf sock 'block 5000)
  (write-command (shepherd-command 'status 'root) sock)

  ;; Close prematurely, right after sending the command.
  (close-port sock))"

$herd status

if "$GUILE" -c '(exit (string=? "2" (major-version)))'
then
    # The 'read' procedure in Guile 2.2 is not suspendable.  Thus, the test
    # below would hang forever in 'scm_read'.
    echo "Running on Guile 2.x; skipping test that requires suspendable 'read'." >&2
else
    "$GUILE" -c "
(use-modules (shepherd comm) (shepherd support) (ice-9 match))

(let ((sock (open-connection \"$socket\")))
  (setvbuf sock 'none)
  (display \"(ah ha!\" sock)
  ;; Leave it hanging; shepherd must not block.
  (let ((sock (open-connection \"$socket\")))
    (write-command (shepherd-command 'status 'does-not-exist) sock)
    (match (read sock)
      (('reply _ ...) #t)
      (x
       (pk 'wrong x)
       (exit 1)))))"

    $herd status
fi

cat "$log"
