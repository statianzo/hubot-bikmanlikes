# Description:
#   A way to interact wih bikman likes stuff
#
# Commands:
#   hubot bikman likes <query> - Posts an image of what bikman likes.
#

fs = require('fs')
url = require('url')
spawn = require('child_process').spawn
nodemailer = require("nodemailer")

module.exports = (robot) ->
  robot.respond /BIKMAN LIKES (.*)/i, (msg) ->
    imageMe msg, msg.match[1], (url) ->
      downloadImage url, (file_name) ->
        mergeImages file_name, (new_file_name) ->
          sendEmail new_file_name, msg.match[1], ->
            cleanUp file_name, new_file_name
            msg.send "Sent to #{process.env.HUBOT_BIKMANLIKES_TARGET_EMAIL} for review"

imageFeatures = (file_name, cb) ->
  output = ""
  identify = spawn 'identify', ["#{__dirname}/../..#{file_name}"]
  identify.stdout.on 'data', (data) ->
    output += data
  identify.stdout.on 'end', (data) ->
    dem = output.split(' ')[2]
    parts = dem.split('x')
    cb width: parseInt(parts[0]), height: parseInt(parts[1])

mergeImages = (file_name, cb) ->
  new_file_name = '/img/' + uniqueId() + '.jpg'
  composite = spawn 'composite', ['-gravity', 'SouthEast', "#{__dirname}/../../img/bikman_like.png", "#{__dirname}/../..#{file_name}", "#{__dirname}/../..#{new_file_name}"]
  composite.stdout.on 'end', (data) ->
    cb(new_file_name)
  composite.stderr.on 'data', (data) ->
    throw data

sendEmail = (file_name, like,  cb) ->
  transport = nodemailer.createTransport "SMTP",
    service: 'Gmail',
    auth:
      user: process.env.HUBOT_BIKMANLIKES_EMAIL,
      pass: process.env.HUBOT_BIKMANLIKES_PASS
  mailOptions =
    from: process.env.HUBOT_BIKMANLIKES_EMAIL,
    to: process.env.HUBOT_BIKMANLIKES_PASS,
    subject: "Bikman likes #{like}",
    attachments: [
      fileName: "image.jpg",
      contents: fs.readFileSync "#{__dirname}/../..#{file_name}"
    ]
  transport.sendMail mailOptions, (err, res) ->
    if err
      throw err
    else
      cb()

cleanUp = (file_name, new_file_name) ->
  fs.unlink "#{__dirname}/../..#{file_name}", ->
  fs.unlink "#{__dirname}/../..#{new_file_name}", ->

downloadImage = (file_url, cb) ->
  file_name = '/tmp/' + uniqueId() + '.jpg'
  file = fs.createWriteStream '.' + file_name
  curl = spawn('curl', [file_url])
  curl.stdout.on 'data', (data) ->
    file.write(data)
  curl.stdout.on 'end', (data) ->
    file.end()
    cb file_name

imageMe = (msg, query, cb) ->
  cb(query) if query.indexOf('http') > -1
  q = v: '1.0', rsz: '8', q: query, safe: 'active', imgsz: 'xxlarge'
  msg.http('http://ajax.googleapis.com/ajax/services/search/images')
    .query(q)
    .get() (err, res, body) ->
      images = JSON.parse(body)
      images = images.responseData.results
      if images.length > 0
        image  = msg.random images
        cb "#{image.unescapedUrl}#.png"

uniqueId = (length=16) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length
