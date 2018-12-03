angular.module('los').service 'EstimateItineraryService', [
  '$q'
  '$http'
  class EstimateItineraryService
    constructor: (@$q, @$http) ->

    get: (estimate_id) ->
      deferred = @$q.defer()

      if estimate_id
        url = "/estimates/#{estimate_id}/itineraries/edit.json"
      else
        url = "/estimates/_/itineraries/new.json"

      @$http.get(url)
        .success (data) =>
          deferred.resolve
            estimate: data.estimate
            caseTypes: data.case_types
            tourTypes: data.tour_types
            airports: data.airports
            arrival_flights: data.arrival_flights
            return_flights: data.return_flights
            areas: data.areas
            busTypes: data.bus_types
            busUseTimes: data.bus_use_times
            facilityTypes: data.facility_types
            languages: data.languages
            guideTypes: data.guide_types
            guideUseTimes: data.guide_use_times
            hotelRanks: data.hotel_ranks
            prefectures: data.prefectures
            regions: data.regions
            transportTypes: data.transport_types
            transportUseTypes: data.transport_use_types
            mealTypes: data.meal_types
            mealTimeTypes: data.meal_time_types
        .error (data) =>
          deferred.reject(data)

      deferred.promise

    update: (estimate_id, estimate) ->
      deferred = @$q.defer()
      @$http.patch "/estimates/#{estimate_id}/itineraries.json",
        { estimate: estimate.attributes() },
        headers:
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      .success (data) ->
        deferred.resolve(data)
      .error (data) ->
        deferred.reject(data)

      deferred.promise

    create: (estimate) ->
      deferred = @$q.defer()

      @$http.post "/estimates/_/itineraries.json",
        { estimate: estimate.attributes() },
        headers:
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      .success (data) ->
        deferred.resolve(data)
      .error (data) ->
        deferred.reject(data)

      deferred.promise

    validate: (estimate_id, estimate) ->
      deferred = @$q.defer()
      @$http.patch "/estimates/#{estimate_id}/validate_itineraries.json",
        { estimate: estimate.attributes() },
        headers:
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      .success (data) ->
        deferred.resolve(data)
      .error (data) ->
        deferred.reject(data)

      deferred.promise


]
