#!/bin/sh

# This script creates a custom html indexpage 
# which displays the host name of the container/pod 
# with a background color given by the HTML_COLOR variable.

DEFAULT_HTML_COLOR="white"
HTML_ROOT_DIR="/usr/share/nginx/html"

[[ -z ${HTML_COLOR} ]] && HTML_COLOR=${DEFAULT_HTML_COLOR}

printf "<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>${HTML_COLOR}</title>
    <style>
      body {
        background-color: ${HTML_COLOR};
      }
    </style>
  </head>
    <body>
        <div style="text-align:center">
          ${HOSTNAME}
        </div>
    </body>
</html>\n" > ${HTML_ROOT_DIR}/index.html
