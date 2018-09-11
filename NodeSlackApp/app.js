var express = require('express')
var request = require('request')
var fs = require('fs')
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
var bodyParser = require('body-parser')
require('dotenv').load();
var app = express()
var urlencodedParser = bodyParser.urlencoded({ extended: false })
const PORT = process.env.PORT || 3000;

function sendMessageToSlackResponseURL(responseURL, JSONmessage){
    var postOptions = {
        uri: responseURL,
        method: 'POST',
        headers: {
            'Content-type': 'application/json'
        },
        json: JSONmessage
    }
    request(postOptions, (error, response, body) => {
        if (error){
            console.log(error)
        }
    })
}

function sendtoJenkins(email,image,responseURL,who){
	var jenkins = require('jenkins')({ baseUrl: `http://${process.env.USERNAME}:${process.env.JENKTOKEN}@MYJENKINSSERVER.COM:8080`, crumbIssuer: false });

	jenkins.job.build({ name: 'buildme', parameters: { imagetype: image,responseurl: responseURL,email: email,whosubmitted: who } }, function(err, data) {
		if (err) {
			throw err
		}
		else
		{
			console.log("Sent to Jenkins")
			console.log(data)
		}
	  });
}

function getUserEmail(actionJSONPayload,callback){
	var formdata = {
				"token": process.env.OAUTHTOKEN,
				"user": actionJSONPayload.user.id
			}

	var postOptions = {
        uri: 'https://slack.com/api/users.info',
        method: 'POST',
		formData: formdata
    }
	

	request(postOptions, (error, response, body) => {
        if (error){
            console.log(error)
        }
		else{
			var parsedBody = JSON.parse(body)
			console.log("EMAILFUNC: "+parsedBody.user.profile.email)
			return callback(parsedBody.user.profile.email)

		}
	})
}

app.post('/slack/actions', urlencodedParser, (req, res) =>{
    res.status(200).end() // best practice to respond with 200 status
    var actionJSONPayload = JSON.parse(req.body.payload) // parse URL-encoded payload JSON string
	console.log(actionJSONPayload.actions[0].name)
		if (actionJSONPayload.actions[0].name == "Cancel")
		{
			var message = {
			"response_type": "ephemeral",
			"replace_original": true,
			"delete_original": true}
			console.log("Cancel")
			sendMessageToSlackResponseURL(actionJSONPayload.response_url, message)
		} 
		else if (actionJSONPayload.actions[0].value == "win10mcsdev"){
			var message = {
			"response_type": "ephemeral",
			"text": ":timer_clock: Deploying Windows 10 MCS DEV Image...",
			"replace_original": true}
			console.log("Entering win10mcsdev")
			sendMessageToSlackResponseURL(actionJSONPayload.response_url, message)
			getUserEmail(actionJSONPayload, function(response){
				sendtoJenkins(response,"dev",actionJSONPayload.response_url,actionJSONPayload.user.id)
			})
		}
		else if (actionJSONPayload.actions[0].value == "win10mcsprod"){
			var message = {
			"response_type": "ephemeral",
			"text": ":timer_clock: Deploying Windows 10 MCS PROD Image...",
			"replace_original": true}
			console.log("Entering win10mcsprod")
			sendMessageToSlackResponseURL(actionJSONPayload.response_url, message)
			getUserEmail(actionJSONPayload, function(response){
				sendtoJenkins(response,"prod",actionJSONPayload.response_url,actionJSONPayload.user.id)
			})
		} 
		else if (actionJSONPayload.actions[0].value == "win10pvs"){
			var message = {
			"response_type": "ephemeral",
			"text": ":timer_clock: Deploying Windows 10 PVS Image...",
			"replace_original": true}
			console.log("Entering win10pvs")
			sendMessageToSlackResponseURL(actionJSONPayload.response_url, message)
			getUserEmail(actionJSONPayload, function(response){
				sendtoJenkins(response,"win10pvs",actionJSONPayload.response_url,actionJSONPayload.user.id)
			})
			
		}
})

//simple test for content switch
app.get('/slack', (req, res) => res.send('Works for me.'))

app.post('/slack/slash-commands/buildme', urlencodedParser, (req, res) =>{
	console.log('entering myvdi command')
    res.status(200).end() // best practice to respond with empty 200 status code
    var reqBody = req.body
    var responseURL = reqBody.response_url
	console.log("Token:" + reqBody.token)
    if (reqBody.token != process.env.APPTOKEN){
        res.status(403).end("Access forbidden")
    }else{
		console.log("sending message")
        var message = {
            "text": "Greatings "+ reqBody.user_name + "! I'm here to help with your image build.  Please select from the options below.",
            "attachments": [
                {
                    "text": "Image Factory",
                    "fallback": "Shame... buttons aren't supported in this land",
                    "callback_id": "button_tutorial",
                    "color": "#B40937",
                    "attachment_type": "default",
                    "actions": [
                        {
                            "name": "Windows 10 MCS (DEV)",
                            "text": ":three_button_mouse: Windows 10 MCS (DEV)",
                            "type": "button",
                            "value": "win10mcsdev",
							"style": "danger",
							"confirm": {
								"title": "Confirm Image Build",
								"text": "Ready to deploy?",
								"ok_text": "Yes",
								"dismiss_text": "No"
							}
                        },
                        {
                            "name": "Windows 10 MCS (PROD)",
                            "text": ":computer: Windows 10 MCS (PROD)",
                            "type": "button",
                            "value": "win10mcsprod",
							"style": "danger",
							"confirm": {
								"title": "Confirm Image Build",
								"text": "Ready to deploy?",
								"ok_text": "Yes",
								"dismiss_text": "No"
							}
						},
						{
                            "name": "Cancel",
                            "text": ":no_entry_sign: Cancel",
                            "type": "button",
                            "value": "nothing"
                        }

                    ]
                }
            ]
        }
        sendMessageToSlackResponseURL(responseURL, message)
    }
})

app.listen(PORT, () => console.log('Listening on ' + PORT + '!'))
