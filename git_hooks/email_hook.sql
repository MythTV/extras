create database email_hook;
grant all privileges on email_hook.* to email_hook@localhost identified by "email_hook";
use email_hook;
CREATE TABLE  `seen` (
 `sha1` VARCHAR( 40 ) NOT NULL ,
 `lastseen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ,
 PRIMARY KEY (  `sha1` )
);
