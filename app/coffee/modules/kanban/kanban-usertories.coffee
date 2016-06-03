###
# Copyright (C) 2014-2016 Taiga Agile LLC <taiga@taiga.io>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: home.service.coffee
###

groupBy = @.taiga.groupBy

class KanbanUserstoriesService extends taiga.Service
    @.$inject = []

    constructor: () ->
        @.userstoriesRaw = []
        @.usByStatus = Immutable.Map()

    init: (project, usersById) ->
        @.project = project
        @.usersById = usersById

    set: (userstories) ->
        @.userstoriesRaw = userstories
        @.refresh()

    add: (us) ->
        @.userstoriesRaw = @.userstoriesRaw.concat(us)
        @.refresh()

    move: (id, statusId, index) ->
        us = @.getUsModel(id)

        usByStatus = _.filter @.userstoriesRaw, (us) =>
            return us.status == statusId

        if us.status != statusId
            usByStatus.splice(index, 0, us)

            us.status = statusId
        else
            index = _.findIndex usByStatus, (it) ->
                return it.id == us.id

            usByStatus.splice(index, 1)
            usByStatus.splice(index, 0, us)

        modified = @.resortUserStories(usByStatus)

        @.refresh()

        return modified

    resortUserStories: (uses) ->
        items = []
        for item, index in uses
            item.kanban_order = index
            if item.isModified()
                items.push(item)

        return items

    replace: (us) ->
        @.usByStatus = @.usByStatus.map (status) ->
            findedIndex = status.findIndex (usItem) ->
                return usItem.get('id') == us.get('id')

            status = status.set(findedIndex, us)

            return status

    replaceModel: (us) ->
        @.userstoriesRaw = _.map @.userstoriesRaw, (usItem) ->
            if us.id == usItem.id
                return us
            else
                return usItem

        @.refresh()

    getUs: (id) ->
        findedUs = null

        @.usByStatus.forEach (status) ->
            findedUs = status.find (us) -> return us.get('id') == id

            return false if findedUs

        return findedUs

    getUsModel: (id) ->
        return _.find @.userstoriesRaw, (us) -> return us.id == id

    refresh: ->
        userstories = @.userstoriesRaw

        _.sortBy(userstories, "kanban_order")

        userstories = _.map userstories, (usModel) =>
            us = {}
            us.isPlaceholder = false
            us.model = usModel.getAttrs()
            us.id = usModel.id
            us.assigned_to = @.usersById[usModel.assigned_to]
            us.colorized_tags = _.map us.model.tags, (tag) =>
                color = @.project.tags_colors[tag]
                return {name: tag, color: color}

            return us

        usByStatus = _.groupBy userstories, (us) ->
            return us.model.status

        # TODO
        # us_archived = []
        # for status in @scope.usStatusList
        #     if not usByStatus[status.id]?
        #         usByStatus[status.id] = []
        #     if @scope.usByStatus?
        #         for us in @scope.usByStatus[status.id]
        #             if us.model.status != status.id
        #                 us_archived.push(us)
        #
        #     # Must preserve the archived columns if loaded
        #     if status.modelis_archived and
        #       @scope.usByStatus? and
        #       @scope.usByStatus[status.id].length != 0
        #         for us in @scope.usByStatus[status.id].concat(us_archived)
        #             if us.model.status == status.id
        #                 usByStatus[status.id].push(us)
        #
        #     usByStatus[status.id] = _.sortBy(usByStatus[status.id], "kanban_order")

        # TODO
        if userstories.length == 0
            status = @.usStatusList[0]
            usByStatus[status.id].push({isPlaceholder: true})

        @.usByStatus = Immutable.fromJS(usByStatus)

        console.log @.usByStatus.toJS()

angular.module("taigaKanban").service("tgKanbanUserstories", KanbanUserstoriesService)
