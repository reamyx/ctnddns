#!/bin/env sh

echo -e "200 OK\nContent-type: text/html\n\n"
echo "\
<!DOCTYPE html>
<html>
    <head>
        <title>CGI GATEWAY OK</title>
    </head>
    <body>
        <p>FCGIWRAP GATEWAY OK.</p>
        <p>$REMOTE_ADDR  $( date )</p>
        <p>zhixia@moon.mn</p>
    </body>
</html>
"
