#!/usr/bin/env node
/* Copyright (c) 2012, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
var urlModule = require("url");
var http = require("http");
var crypto = require("crypto");

var SALT = "@#!mshaker";

var parsedURL = /http:\/\/(.*)\/song\/(\d+)/.exec(process.argv[2]);

if(!parsedURL) {
	console.log("musicake v2 Copyright (c) 2012, Ben Trask. BSD licensed.");
	console.log("Usage: musicake URL > output.mp3");
	console.log("Download a song from musicshake.");
	return;
}

http.get({
	"method": "GET",
	"hostname": parsedURL[1],
	"path": "/APP/getTicketUS.php?SONG_NUM="+parsedURL[2]+"&LANG=Eng",
}, function(res) {
	var ticket = "";
	if(200 !== res.statusCode) return console.log("Status code: "+res.statusCode);
	res.setEncoding("utf8");
	res.addListener("data", function(chunk) {
		ticket += chunk;
	});
	res.addListener("end", function() {
		var parts = ticket.split("||");
		var baseURL = parts[0];
		var ticketID = parts[1];
		var md5 = crypto.createHash("md5");
		md5.update(ticketID+SALT);
		var hash = md5.digest("hex");
		http.get(baseURL+"?TICKET_NUM="+ticketID+"&key="+hash, function(res) {
			if(200 !== res.statusCode) return console.log("Status code: "+res.statusCode);
			res.pipe(process.stdout);
			res.addListener("error", function(err) {
				console.log("Error: "+err);
			});
		});
	});
	res.addListener("error", function(err) {
		console.log("Error: "+err);
	});
});

