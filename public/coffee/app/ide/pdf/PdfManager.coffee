define [
	"ide/pdf/controllers/PdfController"
	"ide/pdf/directives/pdfJs"
], () ->
	class PdfManager
		constructor: (@ide, @$scope) ->

		# All the logic actually happens in the controller
