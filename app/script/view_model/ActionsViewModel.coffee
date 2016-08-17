#
# Wire
# Copyright (C) 2016 Wire Swiss GmbH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.
#

window.z ?= {}
z.ViewModel ?= {}


class z.ViewModel.ActionsViewModel
  constructor: (element_id, @conversation_repository, @user_repository, @conversation_list) ->
    @logger = new z.util.Logger 'z.ViewModel.ActionsViewModel', z.config.LOGGER.OPTIONS

    @action_bubbles = {}
    @selected_conversation = ko.observable()
    @conversations_archived = @conversation_repository.conversations_archived
    @conversations_unarchived = @conversation_repository.conversations_unarchived

    @archive_conversation_tooltip = z.localization.Localizer.get_text {
      id: z.string.tooltip_conversation_list_archive
      replace: {placeholder: '%shortcut', content: z.ui.Shortcut.get_shortcut_tooltip z.ui.ShortcutType.ARCHIVE}
    }
    @notify_conversation_tooltip = z.localization.Localizer.get_text {
      id: z.string.tooltip_conversation_list_notify
      replace: {placeholder: '%shortcut', content: z.ui.Shortcut.get_shortcut_tooltip z.ui.ShortcutType.SILENCE}
    }
    @silence_conversation_tooltip = z.localization.Localizer.get_text {
      id: z.string.tooltip_conversation_list_silence
      replace: {placeholder: '%shortcut', content: z.ui.Shortcut.get_shortcut_tooltip z.ui.ShortcutType.SILENCE}
    }

    # fix for older wrapper versions
    @conversation_list.click_on_archive_action = @click_on_archive_action
    @conversation_list.click_on_block_action = @click_on_block_action
    @conversation_list.click_on_cancel_action = @click_on_cancel_action
    @conversation_list.click_on_clear_action = @click_on_clear_action
    @conversation_list.click_on_leave_action = @click_on_leave_action
    @conversation_list.click_on_mute_action = @click_on_mute_action
    @conversation_list.selected_conversation = @selected_conversation

    @_init_subscriptions()

    ko.applyBindings @, document.getElementById element_id

  _init_subscriptions: =>
    amplify.subscribe z.event.WebApp.SHORTCUT.ARCHIVE, @click_on_archive_action
    amplify.subscribe z.event.WebApp.SHORTCUT.SILENCE, @click_on_mute_action
    amplify.subscribe z.event.WebApp.ACTION.SHOW, @click_on_actions

  click_on_actions: (conversation_et, event) =>
    @selected_conversation conversation_et

    $('.conversation-list-item').removeClass 'hover'
    list_element = $(event.currentTarget.parentNode.parentNode).addClass 'hover'

    if not @action_bubbles[conversation_et.id]
      @action_bubbles[conversation_et.id] = new zeta.webapp.module.Bubble
        host_selector: "##{$(event.currentTarget).attr 'id'}"
        scroll_selector: '.conversation-list-items'
        on_hide: =>
          list_element.removeClass 'hover'
          @action_bubbles[conversation_et.id] = undefined

    @action_bubbles[conversation_et.id].toggle()

    event.stopPropagation()

  click_on_archive_action: =>
    @_click_on_action()
    .then (conversation_et) =>
      @conversation_repository.archive_conversation conversation_et

  click_on_block_action: =>
    @_click_on_action()
    .then (conversation_et) =>
      next_conversation_et = @conversation_repository.get_next_conversation conversation_et
      user_et = conversation_et.participating_user_ets()[0]
      amplify.publish z.event.WebApp.WARNINGS.MODAL, z.ViewModel.ModalType.BLOCK,
        data: user_et.first_name()
        action: => @user_repository.block_user user_et, ->
          amplify.publish z.event.WebApp.CONVERSATION.SWITCH, conversation_et, next_conversation_et

  click_on_cancel_action: =>
    @_click_on_action()
    .then (conversation_et) =>
      next_conversation_et = @conversation_repository.get_next_conversation conversation_et
      @user_repository.cancel_connection_request conversation_et.participating_user_ets()[0], next_conversation_et

  click_on_clear_action: =>
    @_click_on_action()
    .then (conversation_et) =>
      amplify.publish z.event.WebApp.WARNINGS.MODAL, z.ViewModel.ModalType.CLEAR,
        data: conversation_et.display_name()
        conversation: conversation_et
        action: (leave = false) => @conversation_repository.clear_conversation conversation_et, leave

  click_on_leave_action: =>
    @_click_on_action()
    .then (conversation_et) =>
      next_conversation_et = @conversation_repository.get_next_conversation conversation_et
      amplify.publish z.event.WebApp.WARNINGS.MODAL, z.ViewModel.ModalType.LEAVE,
        data: conversation_et.display_name()
        action: => @conversation_repository.leave_conversation conversation_et, next_conversation_et

  click_on_mute_action: =>
    @_click_on_action()
    .then (conversation_et) =>
      @conversation_repository.toggle_silence_conversation conversation_et

  click_on_unarchive_action: =>
    @_click_on_action()
    .then (conversation_et) =>
      @conversation_repository.unarchive_conversation conversation_et, =>
        amplify.publish z.event.WebApp.ARCHIVE.CLOSE if @conversation_repository.conversations_archived().length is 0

  _click_on_action: =>
    return new Promise (resolve) =>
      conversation_et = @selected_conversation() or @conversation_repository.active_conversation()
      if conversation_et
        amplify.publish z.event.WebApp.ARCHIVE.CLOSE if not conversation_et.is_archived()
        @action_bubbles[conversation_et.id]?.hide()
        @selected_conversation null
        resolve conversation_et
      else
        @logger.log @logger.levels.ERROR, 'Cannot complete menu actions as there is no active conversation'
