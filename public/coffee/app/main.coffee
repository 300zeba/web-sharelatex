define [
	"main/project-list"
	"main/user-details"
	"main/account-settings"
	"main/plans"
	"directives/asyncForm"
	"directives/stopPropagation"
	"directives/focus"
	"directives/equals"
	"directives/fineUpload"
	"directives/onEnter"
	"filters/formatDate"
], () ->
	angular.bootstrap(document.body, ["SharelatexApp"])