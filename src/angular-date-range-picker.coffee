angular.module "dateRangePicker", ['pasvaz.bindonce']

angular.module("dateRangePicker").directive "dateRangePicker", ["$compile", ($compile) ->
  # constants
  pickerTemplate = """
  <div ng-show="visible" class="angular-date-range-picker__picker" ng-click="handlePickerClick($event)">
    <div class="angular-date-range-picker__timesheet">
      <button ng-click="move(-1, $event)" class="angular-date-range-picker__prev-month">&#9664;</button>
      <div bindonce ng-repeat="month in months" class="angular-date-range-picker__month">
        <div class="angular-date-range-picker__month-name" bo-text="month.name"></div>
        <table class="angular-date-range-picker__calendar">
          <tr>
            <th bindonce ng-repeat="day in month.weeks[1]" class="angular-date-range-picker__calendar-weekday" bo-text="day.date.format('dd')">
            </th>
          </tr>
          <tr bindonce ng-repeat="week in month.weeks">
            <td
                bo-class='{
                  "angular-date-range-picker__calendar-day": day,
                  "angular-date-range-picker__calendar-day-selected": day.selected,
                  "angular-date-range-picker__calendar-day-disabled": day.disabled,
                  "angular-date-range-picker__calendar-day-start": day.start
                }'
                ng-repeat="day in week track by $index" ng-click="select(day, $event)" bo-text="day.date.date()">
            </td>
          </tr>
        </table>
      </div>
      <button ng-click="move(+1, $event)" class="angular-date-range-picker__next-month">&#9654;</button>
    </div>
    <div class="angular-date-range-picker__panel">
      <div class="angular-date-range-picker__buttons">
        <button ng-click="ok($event)" class="angular-date-range-picker__apply">Apply</button>
        <a ng-click="hide($event)" class="angular-date-range-picker__cancel">cancel</a>
      </div>
    </div>
  </div>
  """

  restrict: "AE"
  replace: true
  template: """
  <span class="angular-date-range-picker__input">
    <span ng-show="model">{{ model.start.format(dateFormat) }} - {{ model.end.format(dateFormat) }}</span>
    <span ng-hide="model">Select date range</span>
  </span>
  """
  scope:
    model: "=ngModel" # can't use ngModelController, we need isolated scope
    change: "&ngChange"
    format: "@"
    template: "="

  link: ($scope, element, attrs) ->
    $scope.dateFormat = $scope.format
    $scope.pickerTemplate = $scope.template
    $scope.dateFormat ?= 'll'
    $scope.pickerTemplate ?= pickerTemplate
    $scope.range = null
    $scope.selecting = false
    $scope.visible = false
    $scope.start = null

    _calculateRange = () ->
      $scope.range = if $scope.selection
        end = $scope.selection.end.clone().endOf("month").startOf("day")
        start = end.clone().subtract(1, "month").startOf("month").startOf("day")
        moment().range(start, end)
      else
        moment().range(
          moment().startOf("month").subtract(1, "month").startOf("day"),
          moment().endOf("month").startOf("day")
        )

    _prepare = () ->
      $scope.months = []
      startIndex = $scope.range.start.year()*12 + $scope.range.start.month()
      startDay = moment().startOf("week").day()

      $scope.range.by "days", (date) ->
        d = date.day() - startDay
        d = 7+d if d < 0 # (d == -1 fix for sunday)
        m = date.year()*12 + date.month() - startIndex
        w = parseInt((7 + date.date() - d) / 7)

        sel = false
        dis = false

        if $scope.start
          sel = date == $scope.start
          dis = date < $scope.start
        else
          sel = $scope.selection && $scope.selection.contains(date)

        $scope.months[m] ||= {name: date.format("MMMM YYYY"), weeks: []}
        $scope.months[m].weeks[w] ||= []
        $scope.months[m].weeks[w][d] =
          date:     date
          selected: sel
          disabled: dis
          start:    ($scope.start && $scope.start.unix() == date.unix())

      # Remove empty rows
      for m in $scope.months
        if !m.weeks[0]
          m.weeks.splice(0, 1)

    $scope.show = () ->
      $scope.selection = $scope.model
      _calculateRange()
      _prepare()
      $scope.visible = true

    $scope.hide = ($event) ->
      $event?.stopPropagation?()
      $scope.visible = false
      $scope.start = null

    $scope.ok = ($event) ->
      $event?.stopPropagation?()
      $scope.model = $scope.selection
      $scope.hide()

    $scope.select = (day, $event) ->
      $event?.stopPropagation?()
      return if day.disabled

      $scope.selecting = !$scope.selecting

      if $scope.selecting
        $scope.start = day.date
        _prepare()
      else
        $scope.selection = moment().range($scope.start, day.date)
        $scope.start = null
        _prepare()

    $scope.move = (n, $event) ->
      $event?.stopPropagation?()
      $scope.range = moment().range(
        $scope.range.start.add(n, 'months').startOf("month").startOf("day"),
        $scope.range.start.clone().add(1, "month").endOf("month").startOf("day")
      )
      _prepare()

    $scope.handlePickerClick = ($event) ->
      $event?.stopPropagation?()

    $scope.$watch "format", (value) -> $scope.dateFormat = value
    $scope.$watch "template", (value) -> $scope.pickerTemplate = value
    $scope.$watch "model", $scope.change

    # create DOM and bind event
    domEl = $compile(angular.element($scope.pickerTemplate))($scope)
    element.append(domEl)

    element.bind "click", (e) ->
      e?.stopPropagation?()
      $scope.$apply ->
        if $scope.visible then $scope.hide() else $scope.show()

    documentClickFn = (e) ->
      $scope.$apply -> $scope.hide()
      true

    angular.element(document).bind "click", documentClickFn

    $scope.$on '$destroy', ->
      angular.element(document).unbind 'click', documentClickFn

    _calculateRange()
    _prepare()
]
