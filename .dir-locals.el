;; Per-directory local variables for GNU Emacs 23 and later.

((nil
  . ((fill-column . 78)
     (tab-width   .  8)
     (sentence-end-double-space . t)

     ;; For use with 'bug-reference-prog-mode'.
     (bug-reference-url-format . "http://bugs.gnu.org/%s")
     (bug-reference-bug-regexp
      . "<https?://\\(debbugs\\|bugs\\)\\.gnu\\.org/\\([0-9]+\\)>")))
 (scheme-mode
  . ((indent-tabs-mode . nil)
     (eval . (put 'let-loop 'scheme-indent-function 2))
     (eval . (put 'with-blocked-signals 'scheme-indent-function 1))
     (eval . (put 'with-process-monitor 'scheme-indent-function 0))
     (eval . (put 'with-service-registry 'scheme-indent-function 0))))
 (texinfo-mode    . ((indent-tabs-mode . nil)
                     (fill-column . 72))))
