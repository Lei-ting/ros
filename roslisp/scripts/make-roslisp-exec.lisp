(require :asdf)

(defun normalize (str)
  (let* ((pos (position #\Newline str))
	 (stripped (if pos
		       (subseq str 0 pos)
		       str)))
    (if (eq #\/ (char stripped (1- (length stripped))))
	stripped
	(concatenate 'string stripped "/"))))

(defun ros-package-path (p)
  (let* ((str (make-string-output-stream))
	 (error-str (make-string-output-stream))
	 (proc (sb-ext:run-program "rospack" (list "find" p) :search t :output str :error error-str))
	 (exit-code (sb-ext:process-exit-code proc)))
    (if (zerop exit-code)
	(pathname (normalize (get-output-stream-string str)))
	(error "rospack find ~a returned ~a with stderr '~a'" 
	       p exit-code (get-output-stream-string error-str)))))


(let ((p (sb-ext:posix-getenv "ROS_ROOT")))
  (unless p (error "ROS_ROOT not set"))
  (let ((roslisp-path (merge-pathnames (make-pathname :directory '(:relative "asdf"))
                                       (ros-package-path "roslisp"))))
    (pprint '(require :asdf))
    (pprint '(push :roslisp-standalone-executable *features*))
    (pprint '(declaim (sb-ext:muffle-conditions sb-ext:compiler-note)))
    (pprint '(load (format nil "~a/.sbclrc-roslisp" (sb-ext:posix-getenv "HOME")) :if-does-not-exist nil))
    (pprint `(push ,roslisp-path asdf:*central-registry*))
    (pprint '(defun roslisp-debugger-hook (condition me)
	      (declare (ignore me))
	      (flet ((failure-quit (&key recklessly-p)
		       (quit :unix-status 1 :recklessly-p recklessly-p)))
		(handler-case
		    (progn
		      (format *error-output*
			      "~&Roslisp exiting due to condition: ~a~&" condition)
		      (finish-output *error-output*)
		      (failure-quit))
		  (condition ()
		    (ignore-errors)
		    (failure-quit :recklessly-p t))))))
    (pprint '(unless (sb-ext:posix-getenv "ROSLISP_BACKTRACE_ON_ERRORS")
	      (setq sb-ext:*invoke-debugger-hook* #'roslisp-debugger-hook)))

    (format t "~&(handler-bind ((style-warning #'muffle-warning) (warning #'print))~%")
    (format t "  (let ((*standard-output* (make-broadcast-stream)))~%")
    (format t "    (asdf:operate 'asdf:load-op :ros-load-manifest :verbose nil)~%")
    (format t "    (asdf:operate 'asdf:load-op :roslisp :verbose nil)))~%")
    (format t "~&(handler-bind ((style-warning #'muffle-warning) (warning #'print) (roslisp::compile-warning #'(lambda (c) (warn ~aReceived roslisp compile warning: ~aa~a (slot-value c 'roslisp::msg) ))))~%" #\" #\~ #\")
    (format t "  (let ((*standard-output* (make-broadcast-stream)))~%")
    (format t "    (asdf:operate 'asdf:load-op ~a~a/~a~a :verbose nil))~%" #\" (second *posix-argv*) (subseq (third *posix-argv*) 1) #\")
    (format t "  (load (merge-pathnames ~aroslisp-init.lisp~a *load-pathname*) :if-does-not-exist nil)~%" #\" #\")
    (format t "  (load (merge-pathnames ~a~a.init.lisp~a *load-pathname*) :if-does-not-exist nil))~%" #\" (fourth *posix-argv*) #\")
    (format t "(handler-bind ((style-warning #'muffle-warning) (warning #'print)) (~a))" (fourth *posix-argv*))
    (format t "~&(sb-ext:quit)~&")))
(sb-ext:quit)