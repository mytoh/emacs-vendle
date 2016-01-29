;;; register -*- lexical-binding: t -*-

;;; Code:

(require 'cl-lib)
(require 'seq)

(require 'hoarder-source-github "hoarder/source/github")
(require 'hoarder-source-git "hoarder/source/git")
(require 'hoarder-package "hoarder/package")
(require 'hoarder-util "hoarder/util")
(require 'hoarder-option "hoarder/option")

;;;; register

(cl-defun hoarder:register (source &optional option)
  (declare (indent 1))
  (pcase source
    ((and (pred file-name-absolute-p)
          (pred file-exists-p))
     (hoarder:handle-register `[:local ,source ,option]))
    (_
     (hoarder:handle-register `[:remote ,source ,option]))))

(cl-defun hoarder:handle-register (variant)
  (pcase variant
    (`[:local ,source ,option]
      (hoarder:register-local
       (hoarder:make-package-local
        (expand-file-name source) option)))
    (`[:remote ,source ,option]
      (hoarder:register-remote
       (hoarder:make-package source option)))))

(cl-defun hoarder:message-register (package)
  (hoarder:log (seq-concatenate 'string "\n* " (glof:get package :name) "\n%s")
               (string-join
                (seq-map
                 (lambda (key)
                   ;; (format "%s: %s"
                   ;;         (symbol-name s)
                   ;;         (slot-value package s))
                   (format "- %s :: %s"
                           (glof:string key)
                           (glof:get package key)))
                 (glof:names package))
                "\n")))

(cl-defun hoarder:register-remote (package)
  (hoarder:resolve-deps package)
  (unless (hoarder:installed? package)
    (hoarder:add-to-load-path package)
    (hoarder:add-to-package-list package)
    (hoarder:option-info package)
    (hoarder:message "registered %s"  (glof:get package :name))
    (hoarder:message-register package)))

(cl-defun hoarder:register-local (package)
  (declare (indent 1))
  (hoarder:add-to-load-path package)
  (hoarder:add-to-package-list package)
  (hoarder:option-info package)
  (hoarder:message "registered %s locally"
                   (glof:get package :name))
  (hoarder:message-register package))

(cl-defun hoarder:register-theme (source &optional option)
  (declare (indent 1))
  (cl-letf* ((mod-option (hoarder:register-theme-default-tag option))
             (package (hoarder:make-package source mod-option)))
    (unless (hoarder:installed? package)
      (hoarder:add-to-theme-path package)
      (hoarder:add-to-load-path package)
      (hoarder:add-to-package-list package)
      (hoarder:message "registered %s as theme"
                       (glof:get package :name))
      (hoarder:message-register package)
      )))

(cl-defun hoarder:register-theme-local (source &optional option)
  (declare (indent 1))
  (cl-letf* ((path (expand-file-name source))
             (package (hoarder:make-package-local path option)))
    (hoarder:add-to-theme-path package)
    (hoarder:add-to-package-list package)
    (hoarder:message "registered %s as local theme"
                     (glof:get package :name))
    (hoarder:message-register package)
    ))


(cl-defun hoarder:register-theme-default-tag (option)
  (cl-letf ((o (glof:get option :tag nil)))
    (pcase o
      (`nil (glof:assoc option
                        :tag "theme"))
      ("theme" option)
      ((pred stringp)
       (glof:assoc option
                   :tag
                   (seq-concatenate 'vector
                                    `[,o]
                                    ["theme"])))
      ((pred (seq-find (lambda (tag) (equal tag "theme"))))
       option)
      (_
       (glof:update option :tag
                    (lambda (tags)
                      (seq-concatenate 'vector
                                       tags
                                       ["theme"])))))))

(cl-defun hoarder:resolve-deps (package)
  (cl-letf ((deps (glof:get package :dependency)))
    (unless (seq-empty-p deps)
      (seq-each
       #'hoarder:install-dep
       deps))
    nil))

(cl-defmethod hoarder:install-dep ((dep list))
  (hoarder:register (cl-first dep)
    (if (cl-rest dep)
        (cl-second dep)
      nil)))

(cl-defmethod hoarder:install-dep ((dep string))
  (hoarder:register dep nil))

(provide 'hoarder-register)

;;; register.el ends here
