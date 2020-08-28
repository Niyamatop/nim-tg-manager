# Copyright (C) 2019 Rupansh Sekar
#
# Licensed under the Raphielscape Public License, Version 1.b (the "License");
# you may not use this file except in compliance with the License.
#

import essentials
from strutils import split, parseInt

import telebot, asyncdispatch, options


proc promoteHandler*(b: TeleBot, c: Command) {.async.} =
    var response = c.message
    let bot = await b.getMe()
    let botChat = await getChatMember(b, $response.chat.id.int, bot.id)
    var promId = 0
    var msgTxt = "Reply to a person to promote them!"
    if not (await canBotPromote(b, response)):
        discard await b.sendMessage(response.chat.id, "I can't promote members!", replyToMessageId = response.messageId)
        return

    if await isUserAdm(b, response.chat.id.int, response.fromUser.get.id):
        if response.replyToMessage.isSome:
            promId = response.replyToMessage.get.fromUser.get.id
        elif ' ' in response.text.get:
            if response.text.get.split(" ").len > 1:
                promId = parseInt(response.text.get.split(" ")[^1])
                if not (await isUserInChat(b, response.chat.id.int, promId)):
                    promId = 0
                    msgTxt = "Invalid user id"

        if promId != 0:
            discard await promoteChatMember(b, $response.chat.id.int, promId,
            canChangeInfo = botChat.canChangeInfo.get,
            canInviteUsers = botChat.canInviteUsers.get,
            canDeleteMessages = botChat.canDeleteMessages.get,
            canRestrictMembers = botChat.canRestrictMembers.get,
            canPinMessages = botChat.canPinMessages.get)
            msgTxt = "Promoted!"
    else:
        msgTxt = "You aren't adm :^("

    discard b.sendMessage(response.chat.id, msgTxt, replyToMessageid = response.messageId)

proc demoteHandler*(b: TeleBot, c: Command) {.async.} =
    var response = c.message
    var demId = 0
    var msgTxt = "Reply to a user to demote them"
    if not (await canBotPromote(b, response)):
        discard await b.sendMessage(response.chat.id, "I can't demote members!", replyToMessageId = response.messageId)
        return

    if await isUserAdm(b, response.chat.id.int, response.fromUser.get.id):
        if response.replyToMessage.isSome:
            demId = response.replyToMessage.get.fromUser.get.id
        elif ' ' in response.text.get:
            if response.text.get.split(" ").len > 1:
                demId = parseInt(response.text.get.split(" ")[^1])
                if not (await isUserInChat(b, response.chat.id.int, demId)):
                    demId = 0
                    msgTxt = "Invalid user id"

        if demId != 0:
            try:
                discard await promoteChatMember(b, $response.chat.id.int, demId,
                    canChangeInfo = false,
                    canInviteUsers = false,
                    canDeleteMessages = false,
                    canRestrictMembers = false,
                    canPinMessages = false)
                msgTxt = "Demoted!"
            except IOError:
                msgTxt = "Failed to demote!"
    else:
        msgTxt = "You aren't adm :^("

    discard await b.sendMessage(response.chat.id, msgTxt, replyToMessageId = response.messageId)

proc pinHandler*(b: TeleBot, c: Command) {.async.} =
    var response = c.message
    var msgTxt: string
    if not (await canBotPin(b, response)):
        discard await b.sendMessage(response.chat.id, "I can't Pin Messages!")
        return

    if response.replyToMessage.isSome:
        if await isUserAdm(b, response.chat.id.int, response.fromUser.get.id):
            discard await pinChatMessage(b, $response.chat.id.int, response.replyToMessage.get.messageId)
        else:
            msgTxt = "You aren't adm :^("
    else:
        msgTxt = "Reply to a message to pin it!"

    discard await b.sendMessage(response.chat.id, msgTxt, replyToMessageId = response.messageId)

proc unpinHandler*(b: TeleBot, c: Command) {.async.} =
    var response = c.message
    if not (await canBotPin(b, response)):
        discard await b.sendMessage(response.chat.id, "I can't unpin Messages!", replyToMessageId = response.messageId)
        return

    if response.text.isSome:
        if await isUserAdm(b, response.chat.id.int, response.fromUser.get.id):
            discard await unpinChatMessage(b, $response.chat.id.int)
        else:
            discard await b.sendMessage(response.chat.id, "You aren't adm :^(", replyToMessageId = response.messageId)

proc inviteHandler*(b: TeleBot, c: Command) {.async.} =
    var response = c.message
    var msgTxt: string

    if response.text.isSome:
        let chat = await getChat(b, $response.chat.id.int)
        if chat.username.isSome:
            msgTxt = "@" & chat.username.get
        elif await canBotInvite(b, response):
            if chat.invitelink.isSome:
                msgTxt = chat.inviteLink.get
            else:
                msgTxt = await exportChatInviteLink(b, $response.chat.id.int)
        else:
            msgTxt = "I do not have permissions to make invite links!"

        discard await b.sendMessage(response.chat.id, msgTxt, replyToMessageId = response.messageId)

proc adminList*(b: TeleBot, c: Command) {.async.} =
    let response = c.message

    let admins = await getChatAdministrators(b, $response.chat.id.int)
    var text = "Admins in this chat:\n"
    for admin in admins:
        if admin.user.username.isSome:
            text = text & admin.user.username.get
        else:
            text = text & admin.user.firstName

        if admin.status == "creator":
            text = text & " (Creator)\n"
        else:
            text = text & "\n"

    discard await b.sendMessage(response.chat.id, text, replyToMessageId = response.messageId)

proc safeHandler*(b: TeleBot, c: Command) {.async.} =
    let response = c.message
    var msgTxt: string

    if await isUserAdm(b, response.chat.id.int, response.fromUser.get.id):
        if not (await canBotInfo(b, response)):
            discard await b.sendMessage(response.chat.id, "I can't change chat permissions!", replyToMessageid = response.messageId)
            return

        var perm: ChatPermissions
        var mode: string
        if ' ' in response.text.get:
            if response.text.get.split(" ").len > 1:
                mode = response.text.get.split(" ")[^1]
                if mode == "on":
                    perm = ChatPermissions(canSendMediaMessages: some(false))
                elif mode == "off":
                    perm = ChatPermissions(canSendMediaMessages: some(true))
                else:
                    msgTxt = "Invalid usage! please use on or off"
        else: 
            discard await setChatPermissions(b, $response.chat.id, perm)
            msgTxt = "Safe mode " & mode

        discard await b.sendMessage(response.chat.id, msgTxt, replyToMessageId = response.messageId)
