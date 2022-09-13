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
var a = 2;
if (someSet.size >= 0) {
 //doNothing
}

connection.connect();
