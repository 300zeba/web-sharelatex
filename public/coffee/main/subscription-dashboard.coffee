define [
	"base"
], (App)->
	SUBSCRIPTION_URL = "/user/subscription/update"

	setupReturly = _.once ->
		recurly?.configure window.recurlyApiKey
	PRICES = {}

	App.controller "CurrenyDropdownController", ($scope, MultiCurrencyPricing, $q)->

		$scope.plans = MultiCurrencyPricing.plans
		$scope.currencyCode = MultiCurrencyPricing.currencyCode

		$scope.changeCurrency = (newCurrency)->
			MultiCurrencyPricing.currencyCode = newCurrency


	App.controller "ChangePlanFormController", ($scope, $modal, MultiCurrencyPricing)->
		setupReturly()
		console.log("init")
		taxRate = window.taxRate

		$scope.changePlan = ->
			$modal.open(
				templateUrl: "confirmChangePlanModalTemplate"
				controller:  "ConfirmChangePlanController"
				scope: $scope
			)

		$scope.$watch "pricing.currencyCode", ->
			$scope.currencyCode = MultiCurrencyPricing.currencyCode

		$scope.pricing = MultiCurrencyPricing
		$scope.plans = MultiCurrencyPricing.plans
		$scope.currencySymbol = MultiCurrencyPricing.plans[MultiCurrencyPricing.currencyCode].symbol

		$scope.currencyCode = MultiCurrencyPricing.currencyCode

		$scope.prices = PRICES
		$scope.refreshPrice = (planCode)->
			if $scope.prices[planCode]?
				return
			$scope.prices[planCode] = "..."
			pricing = recurly.Pricing()
			pricing.plan(planCode, { quantity: 1 }).currency(MultiCurrencyPricing.currencyCode).done (price)->
				totalPriceExTax = parseFloat(price.next.total)
				$scope.$evalAsync () ->
					taxAmmount = totalPriceExTax * taxRate
					if isNaN(taxAmmount)
						taxAmmount = 0
					$scope.prices[planCode] = $scope.currencySymbol + (totalPriceExTax + taxAmmount)

			price = ""



	App.controller "ConfirmChangePlanController", ($scope, $modalInstance, $http)->
		$scope.confirmChangePlan = ->

			body = 
				plan_code: $scope.plan.planCode
				_csrf : window.csrfToken

			$scope.inflight = true


			$http.post(SUBSCRIPTION_URL, body)
				.success ->
					location.reload()
				.error ->
					console.log "something went wrong changing plan"

		$scope.cancel = () ->
			$modalInstance.dismiss('cancel')


	App.controller "UserSubscriptionController", ($scope, MultiCurrencyPricing, $http) ->
		freeTrialEndDate = new Date(subscription.trial_ends_at)

		sevenDaysTime = new Date()
		sevenDaysTime.setDate(sevenDaysTime.getDate() + 7)

		freeTrialInFuture = freeTrialEndDate > new Date()
		freeTrialExpiresUnderSevenDays = freeTrialEndDate < sevenDaysTime

		$scope.view = 'overview'
		$scope.isMonthlyCollab = subscription?.planCode?.indexOf("collaborator") != -1 and subscription?.planCode?.indexOf("ann") == -1
		$scope.stillInFreeTrial = freeTrialInFuture and freeTrialExpiresUnderSevenDays

		setupReturly()

		recurly.Pricing().plan('student', { quantity: 1 }).currency(MultiCurrencyPricing.currencyCode).done (price)->
				totalPriceExTax = parseFloat(price.next.total)
				$scope.$evalAsync () ->
					taxAmmount = totalPriceExTax * taxRate
					if isNaN(taxAmmount)
						taxAmmount = 0
					$scope.currencySymbol = MultiCurrencyPricing.plans[MultiCurrencyPricing.currencyCode].symbol
					$scope.studentPrice = $scope.currencySymbol + (totalPriceExTax + taxAmmount)

		$scope.downgradeToStudent = ->
			body = 
				plan_code: 'student'
				_csrf : window.csrfToken
			$scope.inflight = true
			$http.post(SUBSCRIPTION_URL, body)
				.success ->
					location.reload()
				.error ->
					console.log "something went wrong changing plan"

		$scope.cancelSubscription = ->
			body = 
				_csrf : window.csrfToken
			$scope.inflight = true
			$http.post("/user/subscription/cancel", body)
				.success ->
					location.reload()
				.error ->
					console.log "something went wrong changing plan"



		$scope.switchToCancelationView = ->
			$scope.view = "cancelation"


		$scope.exendTrial = ->
			body = 
				_csrf : window.csrfToken
			$scope.inflight = true
			$http.put("/user/subscription/extend", body)
				.success ->
					location.reload()
				.error ->
					console.log "something went wrong changing plan"



