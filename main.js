var mysql = require('mysql');
var connection = mysql.createConnection(
{
  host:'localhost',
  user: "admin",
  database: "project",
  password: "mypassword", // sensitive
  multipleStatements: true
});
var someSet = 1;
if (someSet.size >= 0) {
 //doNothing
}

var x = 5;

connection.connect();
var arr;
var merged = arr.reduce(function(a, b) {
  a.concat(b);
}); // 
