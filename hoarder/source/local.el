;;; local -*- lexical-binding: t; coding: utf-8; -*-

;;; Code:

(cl-defun hoarder:make-package-local (source option)
  (cl-letf ((name (hoarder:make-package-name-local source option))
            (lpath (hoarder:make-package-load-path-local source option)))
    (glof:plist :type 'local
                :name name
                :path source
                :load-path lpath
                :url ""
                :compile nil
                :build nil
                :info (glof:get option :info nil)
                :origin (glof:get option :origin source)
                :tag (glof:get option :tag nil)
                :desc (glof:get option :desc ""))))

(cl-defun hoarder:make-package-name-local (source option)
  (if option
      (thread-first option
        (glof:get :name)
        (if name (file-name-nondirectory source)))
    (file-name-nondirectory source)))

(cl-defun hoarder:make-package-load-path-local (source option)
  (if option
      (cl-letf ((path (glof:get option :load-path)))
        (if path
            (expand-file-name path source)
          source))
    source))

(cl-defun hoarder:make-package-url-local (source option)
  (if option
      (if-let ((url (glof:get option :url)))
          url "")
    ""))

(provide 'hoarder-source-local)

;;; local.el ends here