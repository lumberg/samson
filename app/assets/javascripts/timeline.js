pusher.constant("MONTHS",
  [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
  ]
);

pusher.constant("DAYS",
  [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
  ]
);

pusher.constant('STATUS_MAPPING',
  {
    "running": "primary",
    "succeeded": "success",
    "failed": "danger",
    "pending": "default",
    "cancelling": "warning",
    "cancelled": "danger"
  }
);

pusher.filter("userFilter",
  function() {
    var hookSources = /^(?:travis|tddium|semaphore)$/i;

    return function(deploys, userType) {
      if (userType !== undefined && userType !== null) {
        return deploys.filter(function(deploy) {
          return (deploy.user.match(hookSources) !== null) === (userType === "Robot");
        });
      }
      return deploys;
    };
  }
);

pusher.filter("stageFilter",
  function() {
    return function(deploys, stageType) {
      if (stageType !== undefined && stageType !== null) {
        return deploys.filter(function(deploy) {
          return deploy.stageType == stageType;
        });
      }
      return deploys;
    };
  }
);

pusher.filter("transformStatus",
  ["STATUS_MAPPING", function(STATUS_MAPPING) {
    return function(status) {
      return STATUS_MAPPING[status];
    };
  }]
);

pusher.filter("dayTime",
  function() {
    return function(local) {
      return local.hour + ":" + local.minute + " " + local.ampm;
    };
  }
);

pusher.filter("fullDate",
  function() {
    return function(local) {
      return local.day + ", " + local.year + " " + local.month + " " + local.date;
    };
  }
);

pusher.filter("localize",
  ["DAYS", "MONTHS", function(DAYS, MONTHS) {
    return function(ms) {
      var localDate = new Date(parseInt(ms));

      var hour   = localDate.getHours(),
          minute = localDate.getMinutes(),
          day    = DAYS[localDate.getDay()],
          year   = localDate.getFullYear(),
          date   = localDate.getDate(),
          month  = MONTHS[localDate.getMonth()],
          ampm   = null;

      if (hour >= 12) {
        if (hour > 12) { hour -= 12; }
        ampm = "PM";
      } else {
        ampm = "AM";
      }

      minute = (minute < 10) ? "0" + minute : minute;

      return {
        hour: hour,
        minute: minute,
        ampm: ampm,
        year: year,
        month: month,
        date: date,
        day: day
      };
    };
  }]
);

pusher.factory("Deploys",
  ["$filter", "$http", "$timeout", function($filter, $http, $timeout) {
    var localize = $filter("localize");

    var Deploys = {
      entries: [],
      page: 1,
      loading: false,
      theEnd: false,

      loadMore: function() {
        if (this.theEnd) { return; }

        Deploys.loading = true;

        $http.get("/deploys/recent.json", { params: { page: Deploys.page } }).
          success(function(data) {
            if (data && data.length) {
              this.page += 1;
            } else if (data.length === 0) {
              this.theEnd = true;
              return;
            }

            for (var i = 0; i < data.length; i++) {
              data[i].time = localize(data[i].time);
              this.entries.push(data[i]);
            }
          }.bind(Deploys)).
          error(function() {
            alert("Failed to load more entries");
          }).
          finally(function() {
            $timeout(function() { this.loading = false; }.bind(Deploys), 500);
          });
      }
    };

    return Deploys;
  }]
);

pusher.controller("TimelineCtrl", ["$scope", "$window", "Deploys",
function($scope, $window, Deploys) {
  $scope.userTypes = ["Human", "Robot"];
  $scope.stageTypes = { "Production": true, "Non-production": false };


  $scope.isSameDate = function(previous, current) {
    if (previous) {
      return previous.date === current.date &&
        previous.month === current.month &&
        previous.year === current.year;
    }
    return false;
  };

  $scope.timelineDeploys = Deploys;

  $scope.timelineDeploys.loadMore();

  angular.element($window).on("scroll", function() {
    if ($window.scrollY >= $window.scrollMaxY - 100 && !$scope.timelineDeploys.loading) {
      $scope.$apply($scope.timelineDeploys.loadMore);
    }
  });

  $scope.shortWindow = function() {
    return !$scope.timelineDeploys.theEnd && $window.scrollMaxY === 0;
  };
}]);
