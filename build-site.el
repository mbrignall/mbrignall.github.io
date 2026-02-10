;; Set the package installation directory so that packages aren't stored in the
;; ~/.emacs.d/elpa path.

(require 'package)
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(package-refresh-contents)

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; Install and load webfeeder
(use-package webfeeder)

;; Load publishing system
(require 'ox-publish)
(use-package htmlize)
(use-package ess)
;; (use-package ox-rss)
(use-package ob-nix)
(use-package esxml)

;;; Sitemap preprocessing
;;;; Get Preview

;; modify with an "if error skip" logic
;; still need conditional
(defun my/get-preview (file)
  "get preview text from a file

Uses the function here as a starting point:
https://ogbe.net/blog/blogging_with_org.html"
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (when (re-search-forward "^#\\+BEGIN_PREVIEW$" nil 1)
      (goto-char (point-min))
      (let ((beg (+ 1 (re-search-forward "^#\\+BEGIN_PREVIEW$" nil 1)))
            (end (progn (re-search-forward "^#\\+END_PREVIEW$" nil 1)
                        (match-beginning 0))))
        (buffer-substring beg end)))))

;;;; Format Sitemap
(defun my-org-publish-org-sitemap (title list)
  "Sitemap generation function."
  (concat "#+TITLE: " title "\n"
          "#+OPTIONS: toc:nil\n\n"
          (org-list-to-subtree list)))

(defun my-org-publish-org-sitemap-format (entry style project)
  "Custom sitemap entry formatting: add date"
  (cond ((not (directory-name-p entry))
         (let* ((file-path (expand-file-name entry (org-publish-property :base-directory project)))
                (preview (or (my/get-preview file-path) "(No preview)")))
           (format "[[file:%s][%s — %s]]\n%s"
                   entry
                   (format-time-string "%Y-%m-%d" (org-publish-find-date entry project))
                   (org-publish-find-title entry project)
                   preview)))
        ((eq style 'tree)
         (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(use-package org-publish-rss
  :vc (:url "https://git.sr.ht/~taingram/org-publish-rss"
            :rev :newest))
(setq org-publish-rss-publish-immediately t)

(setq org-html-postamble-format
      '(("en" "<div class=\"postamble\">
               <p> Created by %c %s </p>
               </div>")))

(defun file-contents (file)
  "Return the contents of FILE as a string, or nil if the file does not exist."
  (if (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (buffer-string))
    (error "File not readable: %s" file)))

(setq org-publish-project-alist
      `(("mblognl"
         :base-directory "./content"
         :html-preamble ,(file-contents "assets/html_preamble.html")
         :html-postamble t
         :recursive t

         ;; --- Sitemap Configuration ---
         :auto-sitemap t
         :sitemap-filename "sitemap.org"
         :sitemap-title "Sitemap"
         :sitemap-sort-files anti-chronologically
         :sitemap-function my-org-publish-org-sitemap
         :sitemap-format-entry my-org-publish-org-sitemap-format
         ;; -----------------------------
         
         :headline-levels 4
         :with-author nil
         :with-creator nil
         :with-tags t
         :with-toc nil
         :section-numbers nil        
         :with-todo-keywords t
         :time-stamp-file nil
         :html-doctype "html5"
         :html-html5-fancy t
         :htmlized-source t   
         :publishing-directory "./public"
         :exclude "^posts/drafts/.*"
         :publishing-function  org-html-publish-to-html
         :rss-link "https://blog.mbrig.nl"
         :auto-rss t
         :org-publish-rss-publish-immediately t
         :rss-title "mblognl"
         :rss-description "mblognl | mbrig.nl"
         :rss-with-content all
         :completion-function org-publish-rss)
        
        ("mblognl:static"
         :base-directory "./assets/img"
         :base-extension "png\\|jpg\\|jpeg"
         :publishing-directory "./public/img"
         :publishing-function org-publish-attachment)
        
        ("mblognl:assets"
         :base-directory "./assets"
         :base-extension "css\\|ico\\|png"
         :publishing-directory "./public"
         :publishing-function org-publish-attachment)
        
        ("blog.mbrig.nl" :components ("mblognl" "mblognl:static" "mblognl:assets"))))


;;; additional settings
(setq org-html-validation-link nil
      org-html-htmlize-output-type 'css
      org-html-style-default (file-contents "./assets/head.html")
      org-export-use-babel t)

(org-babel-do-load-languages
 'org-babel-load-languages
 '((nix . t)))

;; customize export for Nix code blocks
(setq org-src-lang-modes
      (append '(("nix" . nix)) org-src-lang-modes))

;; Generate the site output

(org-publish-all t)
;; (rename-file "./content/rss.xml" "./public/")
(message "Build Complete!")

