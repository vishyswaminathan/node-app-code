var PORT = 8080;
var express = require('express');
var helloapp = express();

var msg = "Hello from v2 node app server, ip: ";
var serverip = "";

require('dns').lookup(require('os').hostname(), function (err, add, fam) {
  serverip = add;
  //console.log(msg + serverip + ":" + PORT);
});

helloapp.get('/', function(req, res) {
  res.send('Welcome to the Node.js App!');
});

helloapp.get('/hello', function(req, res) {
  res.send(msg + serverip + ":" + PORT);
});

helloapp.listen(PORT, function() {
  console.log('Hello app listening on port ' + PORT)
});
