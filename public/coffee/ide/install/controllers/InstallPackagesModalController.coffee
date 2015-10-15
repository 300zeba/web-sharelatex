define [
	"base"
], (App) ->

	App.controller "PackageSearchController", ($scope, $timeout, $http, commandRunner, $interval) ->

		$scope.simple.search = () ->
			post_data =
				language: $scope.engine
				query: $scope.simple.state.searchInput
				_csrf: window.csrfToken
			$scope.simple.state.searching = true
			$http.post("/packages/search", post_data)
				.success (data) ->
					$scope.simple.clearPackageSelection()
					$scope.simple.state.searching = false
					$scope.simple.state.searchResults = data.results
				.error () ->
					$scope.simple.state.searching = false
					console.log ">> seach fail"

		$scope.simple._buildCommandOptions = (item) ->
			options = null
			switch item.provider.source
				when 'conda'
					options = {
						compiler: "command"
						command: [
							"sudo", "conda", "install", "--yes", "--quiet", item.name
						]
					}
				when 'pip'
					options = {
						compiler: "command"
						command: [
							"sudo", "pip", "install", "#{item.name}"
						]
					}
				when 'cran'
					options = {
						compiler: "command"
						command: [
							"sudo", "Rscript", "-e", "install.packages('#{item.name}');
							suppressMessages(suppressWarnings(if(!require('#{item.name}')) {
									stop('Could not load package', call.=FALSE)
							}))"
						]
					}
				when 'apt'
					options = {
						compiler: "apt-get-install"
						package: "#{item.name}"
						env: {
							DEBIAN_FRONTEND: "noninteractive"
						}
					}
				when 'bioconductor'
					options = {
						compiler: "command"
						command: [
							"sudo", "Rscript", "-e",
							"if (!require(BiocInstaller,quietly=TRUE)) {
								source('http://bioconductor.org/biocLite.R')
							} else {
								library(BiocInstaller);
							};
							biocLite('#{item.name}') ;
							suppressMessages(suppressWarnings(if(!require('#{item.name}')) {
								stop('Could not load package', call.=FALSE)
							}))"
						]
					}
				else
					throw new Error("Unrecognized provider source: #{item.provider.source} for #{item.name}")

			options.timeout = 400
			options.parseErrors = false

			return options

		$scope.simple._resetMessages = () ->
			$scope.simple.state.errorMessage = null
			$scope.simple.state.successMessage = null

		$scope.simple.selectPackage = (item) ->
			$scope.simple.state.selected = item

		$scope.simple.clearPackageSelection = () ->
			$scope.simple.state.selected = null

		$scope.simple.stop = () ->
			return if !$scope.simple.state.install?
			commandRunner.stop($scope.simple.state.install)

		$scope.simple.quickInstall = (item) ->
			$scope.simple.selectPackage(item)
			$scope.simple.install(item)

		$scope.simple.install = (item) ->
			options = $scope.simple._buildCommandOptions(item)
			$scope.simple._resetMessages()

			currentRun = commandRunner.run options
			currentRun.packageName = item.name
			$scope.simple.state.install = currentRun

		$scope.simple.showSearchResults = () ->
			$scope.simple.state.searchResults && $scope.simple.state.selected == null

		$scope.simple.showOutput = () ->
			install = $scope.simple.state.install
			install != null && install.packageName == $scope.simple.state.selected.name

		$scope.simple.showStillIniting = () ->
			install = $scope.simple.state.install
			install.running && install.stillIniting && !install.inited



	App.controller "InstallPackagesModalController", ($scope, $modalInstance, $timeout, commandRunner, event_tracking) ->
		$modalInstance.opened.then () ->
			$timeout () ->
				$scope.$broadcast "open"
			, 200

		$scope.install = (autoStart) ->
			return if $scope.inputs.packageName == ""
			$scope.installedPackage = $scope.inputs.packageName

			event_tracking.send("package", "install", {
				name: $scope.installedPackage
			})

			# Don't clear the name on autostart so it's still clear what is going on.
			if !autoStart
				$scope.inputs.packageName = ""

			options = {}
			if $scope.selectedTab.python
				if $scope.inputs.pythonInstaller == "conda"
					package_name = $scope.installedPackage.toLowerCase()
					if result = package_name.match(/(.*)\/(.*)/)
						channel = "https://conda.binstar.org/" + result[1]
						package_name = result[2]
					options = {
						compiler: "command"
						command: if channel? then [
							"sudo", "conda", "install", "--yes", "--quiet", "--channel", channel, package_name
						]
						else [
							"sudo", "conda", "install", "--yes", "--quiet", package_name
						]
					}
				else if $scope.inputs.pythonInstaller == "pip"
					options = {
						compiler: "command"
						command: [
							"sudo", "pip", "install", $scope.installedPackage
						]
						env: {
							HOME: "/usr/local"
						}
					}
				else
					console.error "Unknown python installer: ", $scope.inputs.pythonInstaller
					return
			else if $scope.selectedTab.R
				if $scope.inputs.rInstaller == "install.packages"
					options = {
						compiler: "command"
						command: [
							"sudo", "Rscript", "-e", "install.packages('#{$scope.installedPackage}');
							suppressMessages(suppressWarnings(if(!require('#{$scope.installedPackage}')) {
									stop('Could not load package', call.=FALSE)
							}))"
						]
					}
				else if $scope.inputs.rInstaller == "apt-get"
					package_name = $scope.installedPackage.toLowerCase()
					if not package_name.match(/^r-/)
						package_name = "r-cran-#{package_name}"
					options = {
						compiler: "apt-get-install"
						package: package_name
						env: {
							DEBIAN_FRONTEND: "noninteractive"
						}
					}
				else if $scope.inputs.rInstaller == "git"
					options = {
						compiler: "command"
						command: [
							"sudo", "Rscript", "-e", "library(devtools); install_github('#{$scope.installedPackage}')"
						]
					}
				else if $scope.inputs.rInstaller == "biocLite"
					options = {
						compiler: "command"
						command: [
							"sudo", "Rscript", "-e",
							"if (!require(BiocInstaller,quietly=TRUE)) {
								source('http://bioconductor.org/biocLite.R')
							} else {
								library(BiocInstaller);
							};
							biocLite('#{$scope.installedPackage}') ;
							suppressMessages(suppressWarnings(if(!require('#{$scope.installedPackage}')) {
								stop('Could not load package', call.=FALSE)
							}))"
						]
					}
				else
					console.error "Unknown R installer: ", $scope.inputs.rInstaller
					return
			else
				console.error "Unknown tab!", $scope.selectedTab
				return

			options.timeout = 360
			options.parseErrors = false

			$scope.output.currentRun = commandRunner.run options

		if $scope.autoStart
			$scope.install(true)

		$scope.stop = () ->
			return if !$scope.output.currentRun?
			commandRunner.stop($scope.output.currentRun)

		$scope.help = () ->
			if $scope.installedPackage?
				message = "I'm having trouble installing the '#{$scope.installedPackage}' package."
			else
				message = "I'm having trouble installing a package. (please tell us which one!)"
			Intercom?('showNewMessage', message)
