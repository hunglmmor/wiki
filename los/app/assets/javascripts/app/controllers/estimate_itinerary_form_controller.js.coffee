angular.module('los').controller 'EstimateItineraryFormController', [
  '$scope'
  '$element'
  '$timeout'
  '$interval'
  '$rootScope'
  'EstimateFactory'
  'EstimateItineraryService'
  'EstimateFlightsService'
  'EstimateAirportsService'
  'ItineraryTemplateService'
  'ToggleItemService'
  class EstimateItineraryFormController
    constructor: (@$scope, $element, $timeout, $interval,@$rootScope, Estimate, @losEstimateItinerary, @losEstimateFlights, @losEstimateAirports, @losItineraryTemplate, @losToggleItem) ->
      @estimate_id = $element.data('estimate-id')
      @$timeout = $timeout
      @$interval = $interval
      # 二重投稿防止フラグ
      # @submited = false
      # 画面のsubmitボタンのdisablesで判定する

      @template_name = null
      @templates = null

      @estimate_storage_key_prefix = 'estimatate_'

      if $(location).attr('search').match(/readonly/)
        @is_readonly = true
      else
        @is_readonly = false

      # 一時保存時の日付をJSON.stringifyしたときにJSTからUTCに変わってしまう問題のため一時コメントアウト
      # if @is_readonly == false
        # storage_key = @estimate_storage_key_prefix + @estimate_id
        # storage_data = window.sessionStorage.getItem(storage_key)
        # if storage_data && window.confirm('一時保存データが見つかりました。復元しますか？')
          # @storage_data = storage_data
        # else
          # @storage_data = null
      # # 一時保存フラグの初期化
      # @is_save = null


      @losEstimateItinerary.get(@estimate_id).then(
        (data) =>
          @caseTypes = data.caseTypes
          @tourTypes = data.tourTypes
          @arrival_flights = data.arrival_flights
          @return_flights = data.return_flights
          @airports = data.airports
          @areas = data.areas
          @busTypes = data.busTypes
          @busUseTimes = data.busUseTimes
          @facilityTypes = data.facilityTypes
          @hotelRanks = data.hotelRanks
          @regions = data.regions
          @prefectures = data.prefectures
          @transportTypes = data.transportTypes
          @transportUseTypes = data.transportUseTypes
          @languages = data.languages
          @guideTypes = data.guideTypes
          @guideUseTimes = data.guideUseTimes
          @mealTypes = data.mealTypes
          @mealTimeTypes = data.mealTimeTypes

          # estimate idが一致するものがあれば、ローカルストレージから復元できる
          if @storage_data
            console.log 'load local-savedata'
            @estimate = Estimate.create(JSON.parse(@storage_data))
            @$rootScope.isLocalLoad = true
          else
            @estimate = Estimate.create(data.estimate)
            @$rootScope.isLocalLoad = false
            @estimate.mealTypes = @mealTypes
            @estimate.mealTimeTypes = @mealTimeTypes
            @countTourDay()

          # フライト情報に紐づく旅程のdisabled設定
          @setItineraryDisabled()

          # 一時保存時の日付をJSON.stringifyしたときにJSTからUTCに変わってしまう問題のため一時コメントアウト
          # if @is_readonly == false
            # @start_interval()
        (error) -> console.error(error)
      )

    createItineraryDailies: (event, days) ->
      event.preventDefault()
      if @estimate.itinerary_dailies.length <= 0
        @estimate.createItineraryDailies(days)
        @syncInFlight()
        @syncOutFlight()

    addPrev: (event, day_no) ->
      event.preventDefault()
      @estimate.insertItineraryDailyPrev(day_no)

    addNext: (event, day_no) ->
      event.preventDefault()
      @estimate.insertItineraryDailyNext(day_no)

    movePrev: (event, day_no) ->
      event.preventDefault()
      @estimate.moveItineraryDaily(day_no, -1)

    moveNext: (event, day_no) ->
      event.preventDefault()
      @estimate.moveItineraryDaily(day_no, 1)

    clear: (event, day_no) ->
      event.preventDefault()
      @estimate.clearItineraryDaily(day_no)

    selectTemplate: (event, day_no, template) ->
      event.preventDefault()
      # クリアしてから
      @clear(event, day_no)
      @estimate.setTemplate(day_no, template)
      $('div.modal-backdrop.in').remove()
      $('body').removeClass('modal-open')
      ''

    remove: (event, day_no) ->
      event.preventDefault()
      @estimate.deleteItineraryDaily(day_no)

    addEstimateTour: (event) ->
      event.preventDefault()
      @estimate.estimate_tours.push
        id: null
        japan_arv_date_from: null
        japan_arv_date_to: null

    removeEstimateTour: (event, index) ->
      event.preventDefault()
      @estimate.estimate_tours.splice(index, 1)
    #XXX: 定額ツアーにおける初日除外日のノード追加処理、除外日機能削除により不要になっているが不具合確認のため保持
    addEstimateExcludedDay: (event) ->
      event.preventDefault()
      @estimate.estimate_excluded_days.push
        id: null
        excluded_date: null


    selectEstimateInFlightDate: () ->
      console.log @estimate.in_flight_date.getTime()
      console.log @estimate.out_flight_date.getTime()
      if @estimate.in_flight_date>@estimate.out_flight_date
        @estimate.out_flight_date = @estimate.in_flight_date

    selectEstimateFlightNumber: (item) ->
      # flight numberをselectで取得するように変更 2017.02.02
      @losEstimateFlights.get(@estimate[item].flight_number).then(
        (data) =>
          if data?
            _strToTime = (str) ->
              return null unless str
              t = str.split(':')
              new Date(1970, 0, 1, parseInt(t[0], 10), parseInt(t[1], 10), 0)
            if item is 'in_flight_ca_no'
              @estimate.in_flight_time = _strToTime(data.str_time)
              # 初回入力、null時の修正
              if @estimate.in_flight_airport is null
                @estimate.in_flight_airport = {}
              # XXX: iata_idはsyncInFlightで利用しているので削除しないように！
              # 対応するパラメータ詰め替え処理: estimates/itineraries_controller.rb#build_update_params
              @estimate.in_flight_airport.iata_id = data.iata_id
              @estimate.in_flight_airport.id = data.airport_id
            else if item is 'out_flight_ca_no'
              @estimate.out_flight_time = _strToTime(data.str_time)
              # 初回入力、null時の修正
              if @estimate.out_flight_airport is null
                @estimate.out_flight_airport = {}
              # XXX: iata_idはsyncOutFlightで利用しているので削除しないように！
              # 対応するパラメータ詰め替え処理: estimates/itineraries_controller.rb#build_update_params
              @estimate.out_flight_airport.iata_id = data.iata_id
              @estimate.out_flight_airport.id = data.airport_id
        (error) -> console.error(error)
      ).finally(
        () =>
          @syncInFlight() if item is 'in_flight_ca_no'
          @syncOutFlight() if item is 'out_flight_ca_no'
      )

    #XXX: 定額ツアーにおける初日除外日のノード削除処理、除外日機能削除により不要になっているが不具合確認のため保持
    removeEstimateExcludedDay: (event, index) ->
      event.preventDefault()
      @estimate.estimate_excluded_days.splice(index, 1)
      @countTourDay()

    countTourDay: () ->
      if @estimate.estimate_tours.length && @estimate.estimate_tours[0].japan_arv_date_from? && @estimate.estimate_tours[0].japan_arv_date_to?
        msDateFrom = new Date(@estimate.estimate_tours[0].japan_arv_date_from).getTime()
        msDateTo = new Date(@estimate.estimate_tours[0].japan_arv_date_to).getTime()
        msDiff = msDateTo - msDateFrom
        @days = Math.floor(msDiff / (1000 * 60 * 60 * 24)) + 1

        #XXX: 定額ツアーにおける初日除外日を含めたツアー初日の総数カウント処理、除外日機能削除により不要になっているが既存データとの整合性のため保持
        if @estimate.estimate_excluded_days? && @estimate.estimate_excluded_days.length
          for excluded_day in @estimate.estimate_excluded_days
            if msDateFrom <= new Date(excluded_day.excluded_date).getTime() <= msDateTo
              @days--


        if @days < 1
          @days = 0
        else
          @$timeout( () ->
            $('#createItineraryDailiesBtn').trigger('click')
          , 0)
      # estimate_toursが無い、つまり最初の旅程作成タイミング
      else
        @days = @estimate.tour_day_count
        # もし無効な値なら
        unless @days
          @days = 1
        # 初期入力状態生成
        @$timeout( () ->
          $('#createItineraryDailiesBtn').trigger('click')
        , 0)

      return @days

    bindAdultCount: () ->
      for itinerary_daily in @estimate.itinerary_dailies
        itinerary_daily.adult_count = @estimate.adult_count

    bindChildCount: () ->
      for itinerary_daily in @estimate.itinerary_dailies
        itinerary_daily.child_count = @estimate.child_count

    bindChildCountNoMeal: () ->
      for itinerary_daily in @estimate.itinerary_dailies
        itinerary_daily.child_count_no_meal = @estimate.child_count_no_meal

    bindInfantCount: () ->
      for itinerary_daily in @estimate.itinerary_dailies
        itinerary_daily.infant_count = @estimate.infant_count

    bindTourLeaderCount: () ->
      for itinerary_daily in @estimate.itinerary_dailies
        itinerary_daily.tour_leader_count = @estimate.tour_leader_count

	# MOR: Get local timezone hours
    getTimeZoneHoursClient: () ->
      today = new Date()
      offset = -(today.getTimezoneOffset()/60)
      return offset
      
    # AngularJSのバグ
    fixDateUtcToLocal: () ->
      # in_flight_date
      in_flight_date = new Date(@estimate.in_flight_date)
      in_flight_date.setHours(in_flight_date.getHours() + 9)
      @estimate.in_flight_date = in_flight_date

      # out_flight_date
      out_flight_date = new Date(@estimate.out_flight_date)
      out_flight_date.setHours(out_flight_date.getHours() + 9)
      @estimate.out_flight_date = out_flight_date
		
	  # japan_arv_date_from
	  iHours = @getTimeZoneHoursClient()
      japan_arv_date_from = new Date(@estimate.estimate_tours[0].japan_arv_date_from)
      japan_arv_date_from.setHours(japan_arv_date_from.getHours() + iHours)
      @estimate.estimate_tours[0].japan_arv_date_from = japan_arv_date_from
      
    # 送信処理の復活
    turnOnSubmit: () ->
      $('.itinerary-submit').prop('disabled', false)
      $('.itinerary-submit-message').toggle()
      $('.itinerary-submit-alert').toggle()
      $('.itinerary-submit-error').hide()
      $('.itinerary-submit-badrequest').hide()

    # 送信処理の無効化＆メッセージ表示
    turnOffSubmit: () ->
      if $('.itinerary-submit').is(':disabled')
        return false
      $('.itinerary-submit').prop('disabled', true)
      $('.itinerary-submit-message').show()
      $('.itinerary-submit-alert').hide()
      $('.itinerary-submit-error').hide()
      $('.itinerary-submit-badrequest').hide()
      return true

    save: (event) ->
      event.preventDefault()
      # 送信処理の無効化
      if !@turnOffSubmit()
        return
      # pre validation
      @estimate.tour_day_count = @estimate.itinerary_dailies.length
      # fix date
      @fixDateUtcToLocal()

      console.log 'Do Pre Validate'
      @losEstimateItinerary.validate(@estimate_id, @estimate).then(
        (data) =>
          @validationResult = data
          console.log data
          console.log '@validationResult=' + @validationResult
          if @validationResult
            @reflect_validation_result()
            # バリデーション後にボタン無効を回避する
            @turnOnSubmit()
          else
            @valid_save()
        ,
        (data) ->
          $('.itinerary-submit').prop('disabled', false)
          $('.itinerary-submit-message').hide()
          $('.itinerary-submit-alert').hide()
          $('.itinerary-submit-error').show()
          $('.itinerary-submit-badrequest').hide()
          console.error data
      )

    # Do Save
    valid_save: () ->
      # Do Save
      console.log 'Do Save'
      # save
      if @estimate_id
        console.log 'Update'
        console.log 'Update'+@estimate
        @losEstimateItinerary.update(@estimate_id, @estimate).then(
          (data) =>
            if data is 'bad_request'
              $('.itinerary-submit').prop('disabled', true)
              $('.itinerary-submit-message').hide()
              $('.itinerary-submit-alert').hide()
              $('.itinerary-submit-error').hide()
              $('.itinerary-submit-badrequest').show()
            else
              # saveしたらsessionの一時保存を消去する
              storage_key = @estimate_storage_key_prefix + @estimate_id
              window.sessionStorage.removeItem storage_key

              $(window).off 'beforeunload'
              location.href = "/estimates/#{@estimate_id}"
          ,
          (data) ->
            $('.itinerary-submit').prop('disabled', false)
            $('.itinerary-submit-message').hide()
            $('.itinerary-submit-alert').hide()
            $('.itinerary-submit-error').show()
            $('.itinerary-submit-badrequest').hide()
            console.error data
        )
      else
        console.log 'Create'
        @estimate.ng_meal = ''
        @losEstimateItinerary.create(@estimate).then(
          (data) =>
            # saveしたらsessionの一時保存を消去する
            storage_key = @estimate_storage_key_prefix + @estimate_id
            window.sessionStorage.removeItem storage_key

            $(window).off 'beforeunload'
            location.href = "/estimates/templates"
          ,
          (data) ->
            $('.itinerary-submit').prop('disabled', false)
            $('.itinerary-submit-message').hide()
            $('.itinerary-submit-alert').hide()
            $('.itinerary-submit-error').show()
            $('.itinerary-submit-badrequest').hide()
            console.error data
        )

    # Reflection
    reflect_validation_result: () ->
      # 各部のエラー表示部分のリセット
      # FIXME: もうちょっと綺麗な方法が必要
      targetIdList = [
        "case_type",
        "tour_type",
        "course_in_prefecture",
        "course_out_prefecture",
        "estimate_tours_0_japan_arv_date_to",
        "estimate_tours_0_japan_arv_date_from",
        "adult_count",
        "estimateForm.validationResult.estimate.adult_count",
        "child_count",
        "child_count_no_meal",
        "infant_count",
        "tour_leader_count",
        "guide_count",
        "driver_count",
        "in_flight_date",
        "in_flight_ca_no",
        "in_flight_time",
        "in_flight_airport",
        "out_flight_date",
        "out_flight_ca_no",
        "out_flight_time",
        "out_flight_airport",
        "ng_meal",
        "remarks"]
      for targetId in targetIdList
        $('#'+targetId).removeClass('ng-invalid').addClass('ng-valid')

      subArrayIdList = [
        "estimate_tour",
        "estimate_tours",
# XXX:除外日機能削除 に伴い不要
#        "estimate_excluded_day",
#        "estimate_excluded_days",
        "itinerary_daily",
        "itinerary_dailies"
      ]

      # Estimateノード用のエラー表示処理
      if @validationResult.estimate
        for targetId,errorMessages  of @validationResult.estimate
          console.log "targetId="+targetId
          unless targetId in subArrayIdList
            console.log targetId
            $('#'+targetId).removeClass('ng-valid').addClass('ng-invalid')

      # Estimate Toursノード用のエラー表示処理
      if @validationResult.estimate.estimate_tours
        for indexNo,targetObj  of @validationResult.estimate.estimate_tours
          for targetId,errorMessages  of targetObj
            console.log "estimate_tours: targetId="+targetId
            $('#estimate_tours_'+indexNo+'_'+targetId)
              .removeClass('ng-valid')
              .addClass('ng-invalid')

      # Itineray Daily以下のエラー処理
      if @validationResult.estimate.itinerary_dailies
        # Daily Loop処理
        for dayNo,itinerayDaily  of @validationResult.estimate.itinerary_dailies
          # itineraryDaily Count
          @set_result_to_itinerary_dailies(dayNo, itinerayDaily)
          # Itinerary
          @set_result_to_itineraries(dayNo, itinerayDaily)
          # Bus
          @set_result_to_itinerary_buses(dayNo, itinerayDaily)
          # Guides
          @set_result_to_itinerary_guides(dayNo, itinerayDaily)
          # Hotels
          @set_result_to_itinerary_hotels(dayNo, itinerayDaily)
          # Meals
          @set_result_to_itinerary_meals(dayNo, itinerayDaily)
          # Other

    # Itinerary set error bg
    set_result_to_itineraries: (dayNo, itineraryDaily) ->
      #target fields
      targetFields = [
        "itinerary_daily_id",
        "day_no",
        "prefecture_id",
        "area_id",
        "sub_area_id",
        "is_document_display",
        "item_id",
        "item_name",
        "item_no",
        "item_type_id",
        "rough_utilization_time",
        "arrival_time",
        "departure_time",
        "is_use_highway",
        "is_use_parking",
        "facility_tariff_id",
        "transport_use_type_id",
        "itinerary_word",
        "is_use_parking",
        "master_charge",
        "offset_charge",
        "ticket_type_id"
      ]
      #prefix
      prefixName = 'itinerary'
      #models
      targetModels = itineraryDaily.itineraries
      @set_result_to_itinerary_fields(dayNo, targetModels, targetFields, prefixName)


    # ItineraryBus set error bg
    set_result_to_itinerary_buses: (dayNo, itineraryDaily) ->
      #target fields
      targetFields = [
        "region_id",
        "bus_type_id",
        "bus_use_time_id",
        "count",
        "stay_count"
      ]
      #prefix
      prefixName = 'bus'
      #models
      targetModels = itineraryDaily.itinerary_buses
      @set_result_to_itinerary_fields(dayNo, targetModels, targetFields, prefixName)

    # ItineraryGuide set error bg
    set_result_to_itinerary_guides: (dayNo, itineraryDaily) ->
      #target fields
      targetFields = [
        "language_id",
        "guide_type_id",
        "guide_use_time_id",
        "is_stay"
      ]
      #prefix
      prefixName = 'guide'
      #models
      targetModels = itineraryDaily.itinerary_guides
      @set_result_to_itinerary_fields(dayNo, targetModels, targetFields, prefixName)

    # ItineraryHotel set error bg
    set_result_to_itinerary_hotels: (dayNo, itineraryDaily) ->
      #target fields
      targetFields = [
        "hotel_id",
      ]
      #prefix
      prefixName = 'hotel'
      #models
      targetModels = itineraryDaily.itinerary_hotels
      @set_result_to_itinerary_fields(dayNo, targetModels, targetFields, prefixName)

    # ItineraryMeal set error bg
    set_result_to_itinerary_meals: (dayNo, itineraryDaily) ->
      #target fields
      targetFields = [
        "meal_type_id",
      ]
      #prefix
      prefixName = 'meal'
      #models
      targetModels = itineraryDaily.itinerary_meals
      @set_result_to_itinerary_fields(dayNo, targetModels, targetFields, prefixName)

    # ItineraryMealRestaurant set error bg
    set_result_to_itinerary_meal_restaurants: (dayNo, itineraryDaily) ->
      #target fields
      targetFields = [
        "remarks",
      ]
      #prefix
      prefixName = 'meal'
      #models
      meals = itineraryDaily.itinerary_meals
      for mealIndexNo,meal of meals
        restaurants = meal.itinerary_restaurants
        #prefix
        prefix = 'day_'+dayNo+'_meal_'+mealIndexNo+'_restaurant_'
        # set valid
        @set_valid_to_fields(targetFields,prefix)
        #for error fields
        if restaurants
          # set invalid
          @set_invalid_to_fields(targetFields,prefix,restaurants)



    # ItineraryDaily set error bg
    set_result_to_itinerary_dailies: (dayNo, itineraryDaily) ->
      #target fields
      targetFields = [
        "adult_count",
        "child_count",
        "child_count_no_meal",
        "infant_count",
        "tour_leader_count",
      ]
      #prefix
      prefix = 'day_'+dayNo
      targetModels = [itineraryDaily]
      # set valid
      @set_valid_to_fields_without_cnt(targetFields,prefix)
      #for error fields
      if targetModels
        # set invalid
        @set_invalid_to_fields_without_cnt(targetFields,prefix,targetModels)

    # ItineraryGuide set error bg
    set_result_to_itinerary_fields: (dayNo, targetModels, targetFields, prefixName) ->
      #prefix
      prefix = 'day_'+dayNo+'_'+prefixName+'_'
      # set valid
      @set_valid_to_fields(targetFields,prefix)
      #for error fields
      if targetModels
        # set invalid
        @set_invalid_to_fields(targetFields,prefix,targetModels)

    set_invalid_to_fields: (fields,prefix,objList) ->
      for indexNo,targetObj  of objList
        for fieldName,errorMessages of targetObj
          console.log "fieldName="+fieldName
          if fieldName in fields
            console.log "fieldName="+fieldName
            @set_invalid(prefix+indexNo+'_'+fieldName)

    set_invalid_to_fields_without_cnt: (fields,prefix,objList) ->
      for indexNo,targetObj  of objList
        for fieldName,errorMessages of targetObj
          console.log "fieldName="+fieldName
          if fieldName in fields
            console.log "fieldName="+fieldName
            @set_invalid(prefix+'_'+fieldName)


    set_valid_to_fields: (fields,prefix) ->
      cnt = 0
      while( $('#'+prefix+cnt).length>0 )
        for target in fields
          @set_valid(prefix+cnt+'_'+target)
        cnt += 1

    set_valid_to_fields_without_cnt: (fields,prefix) ->
      while( $('#'+prefix).length>0 )
        for target in fields
          @set_valid(prefix+'_'+target)

    set_valid: (id) ->
      console.log "setValidBg: id="+id
      $('#'+id).removeClass('ng-invalid').addClass('ng-valid')

    set_invalid: (id) ->
      console.log "setErrorBg: id="+id
      $('#'+id).removeClass('ng-valid').addClass('ng-invalid')

    # Validation
    validate: (event) ->
      event.preventDefault()
      @estimate.tour_day_count = @estimate.itinerary_dailies.length
      console.log 'Do Validate'
      @losEstimateItinerary.validate(@estimate_id, @estimate).then(
        (data) =>
          @validationResult = data
          console.log data
          if @validationResult
            @reflect_validation_result()
        ,
        (data) ->
          console.error data
      )

    # フライトの同期（到着）
    syncInFlight: ->
      itineraryDaily = @estimate.getFirstItineraryDaily()
      airport = itineraryDaily.findOrInsertInFlightAirport()
      if @estimate.in_flight_airport?.iata_id?
        @losEstimateAirports.get(@estimate.in_flight_airport.iata_id).then(
          (data) =>
            airport.setAirport(data)
            airport.$controller.selectPrefecture()
            airport.$controller.selectArea()
            airport.arrival_time = @estimate.in_flight_time
            airport.disabled_flg = true
          (data) ->
            console.error data
        )

    # フライトの同期（帰国）
    syncOutFlight: ->
      itineraryDaily = @estimate.getLastItineraryDaily()
      airport = itineraryDaily.findOrInsertOutFlightAirport()
      if @estimate.out_flight_airport?.iata_id?
        @losEstimateAirports.get(@estimate.out_flight_airport.iata_id).then(
          (data) =>
            airport.setAirport(data)
            airport.$controller.selectPrefecture()
            airport.$controller.selectArea()
            airport.departure_time = @estimate.out_flight_time
            airport.disabled_flg = true
          (data) ->
            console.error data
        )

    # フライト情報に紐づく旅程のdisabled設定
    setItineraryDisabled: ->
      firstItineraryDaily = @estimate.getFirstItineraryDaily()
      if firstItineraryDaily
        firstAirports = firstItineraryDaily.findAirports()
        if @estimate.in_flight_airport?.iata_id? and !_.isEmpty(firstAirports)
          @losEstimateAirports.get(@estimate.in_flight_airport.iata_id).then(
            (data) =>
              for airport in firstAirports
                if airport.checkAirport(data)
                  airport.disabled_flg = true
                  break
            (data) ->
              console.error data
          )

      lastItineraryDaily = @estimate.getLastItineraryDaily()
      if lastItineraryDaily
        lastAirports = lastItineraryDaily.findAirports()
        if @estimate.out_flight_airport?.iata_id? and !_.isEmpty(lastAirports)
          @losEstimateAirports.get(@estimate.out_flight_airport.iata_id).then(
            (data) =>
              for airport in lastAirports by -1
                if airport.checkAirport(data)
                  airport.disabled_flg = true
                  break
            (data) ->
              console.error data
          )
    # 一時保存時の日付をJSON.stringifyしたときにJSTからUTCに変わってしまう問題のため一時コメントアウト
    # start_interval: ->
      # timer = @$interval(
        # (factory)->
          # id = factory.estimate_id
          # object = factory.estimate
          # prefix = factory.estimate_storage_key_prefix
          # # objectを更新

          # save_kes = prefix + id
          # if factory.is_save == null
            # # 既にsaveがあるか？
            # storage_data = window.sessionStorage.getItem(save_kes)
            # if storage_data
              # factory.is_save = confirm('一時保存を試みましたが、既に一時保存されているデータがみつかりました。上書きしますか？\n' +
                                        # '上書きをキャンセルする場合は、今回の編集について、一時保存機能が無効になります。')
            # else
              # # 上書き対象のデータがないのであれば、保存する
              # factory.is_save = true

          # if factory.is_save
            # window.sessionStorage.setItem(save_kes, JSON.stringify(object.attributes()))
            # console.log 'local-save,' + save_kes

      # , 60000, 0, true, @)


    # 旅程テンプレートの検索
    searchItineraryTemplate: (event, template_name) ->
      event.preventDefault()
      @losItineraryTemplate.search(template_name).then(
        (data) => @templates = data
        (error) -> console.error(error)
      )

    copyBusAllDay: (event, day_no, index) ->
      event.preventDefault()
      org_itinerary_daily = @estimate.itinerary_dailies.filter((itinerary_daily) ->
        itinerary_daily.day_no is day_no
        )[0]
      org_itinerary_bus = org_itinerary_daily.itinerary_buses[index]

      $.each @estimate.itinerary_dailies, (_, itinerary_daily) ->
        itinerary_daily.copyBus(day_no, index, org_itinerary_bus)

    copyGuideAllDay: (event, day_no, index) ->
      event.preventDefault()
      org_itinerary_daily = @estimate.itinerary_dailies.filter((itinerary_daily) ->
        itinerary_daily.day_no is day_no
        )[0]
      org_itinerary_guide = org_itinerary_daily.itinerary_guides[index]

      $.each @estimate.itinerary_dailies, (_, itinerary_daily) ->
        itinerary_daily.copyGuide(day_no, index, org_itinerary_guide)

    # itemの表示／非表示
    toggleItem: (event) ->
      @losToggleItem.change(event)
]
