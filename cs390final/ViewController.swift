//
//  ViewController.swift
//  cs390final
//
//  Created by Jucong He on 4/23/18.
//  Copyright © 2018 JucongHe. All rights reserved.
//

import UIKit
import Speech
import CocoaMQTT
import ApiAI
import MediaPlayer
import EventKit
import SwiftyJSON

class ViewController: UIViewController {
    let host = "io.adafruit.com"
    let username = "Jucong"
    let pass = "01a85723468e409bb15488a77efe724c"
    let pubPath = "Jucong/feeds/publish"
    
    let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    
    let player = MPMusicPlayerController.systemMusicPlayer()
    let eventStore = EKEventStore()
    
    var todayEvent: String?
    
    var mqttClient: CocoaMQTT?
    
    var weatherCond :String?
    var temperature :String?

    @IBOutlet weak var connectionStatus: UILabel!
    @IBOutlet weak var micBtn: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mqttSetting()
        print("Connecting so server")
        mqttClient!.connect()
        recognizer!.delegate = self
        micSetup()
        calSetup()
        getWeather()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func mqttSetting() {
        let clientID = "IOS Phone";
        mqttClient = CocoaMQTT(clientId: clientID, host: self.host, port: 1883)
        mqttClient!.username = self.username
        mqttClient!.password = self.pass
        mqttClient!.keepAlive = 60
        mqttClient!.delegate = self
    }
    
    func micSetup(){
        var isButtonEnabled = false
        SFSpeechRecognizer.requestAuthorization { (status) in
            switch status {
            case .authorized:
                isButtonEnabled = true
                
            default:
                isButtonEnabled = false
            }
        }
        OperationQueue.main.addOperation() {
            self.micBtn.isEnabled = isButtonEnabled
        }
    }
    
    func calSetup() {
        eventStore.requestAccess(to: .event) { (grand, error) in
            if grand {
                self.todayEvent = self.getTodayEvent()
            } else {
                print("dont have access")
            }
        }
    }
    
    func getIntent(text: String){
        let request = ApiAI.shared().textRequest()
        request?.query = text
        
        request?.setMappedCompletionBlockSuccess({ (request, response) in
            let response = response as! AIResponse
            switch response.result.action {
            case "welcome":
                self.speak(text: response.result.fulfillment.speech)
                self.mqttClient!.publish(self.pubPath, withString: "0" + "0")
            case "home":
                self.speak(text: response.result.fulfillment.speech)
                self.mqttClient!.publish(self.pubPath, withString: "0" + "0")
            case "schedule":
                if self.todayEvent != nil {
                    self.speak(text: response.result.fulfillment.speech)
                    self.mqttClient!.publish(self.pubPath, withString: "4")
                }
            case "weather":
                self.speak(text: response.result.fulfillment.speech + "\(self.weatherCond!)")
                self.publishWeatherHelper()
            case "music":
                self.speak(text: response.result.fulfillment.speech + self.getPlayingSong())
                self.mqttClient!.publish(self.pubPath, withString: "5")
            case "temp":
                self.speak(text: response.result.fulfillment.speech + "\(self.temperature!) degrees")
                self.mqttClient!.publish(self.pubPath, withString: "6" + self.temperature!)
            default:
                self.speak(text: response.result.fulfillment.speech)
            }
        }, failure: { (request, error) in
            print("Error in getting intent")
        })
        
        ApiAI.shared().enqueue(request)
    }
    
    func getPlayingSong() -> String {
        if let currentTrack = player.nowPlayingItem {
            return currentTrack.title!
        }
        return ""
    }
    
    func getWeather(){
        let url = URL(string: "http://samples.openweathermap.org/data/2.5/weather?zip=01003,us&appid=7ca833e42d6524522643a7a64006d9eb")
        let req = URLRequest(url: url!)
        let task = URLSession.shared.dataTask(with: req) { (data, res, err) in
            if let weatherdata = data {
                let json = JSON(data: weatherdata)
                self.weatherCond =  json["weather"].arrayValue[0]["main"].string!
                let tempKel = json["main"]["temp"].double!
                self.temperature = String(Int(tempKel - 273.15))
                self.mqttClient!.publish(self.pubPath, withString: "6" + self.temperature!)
            }
        }
        task.resume()
    }
    
    func publishWeatherHelper()  {
        switch weatherCond! {
        case "Sunny":
            mqttClient!.publish(self.pubPath, withString: "7" + "1")
        case "Rain":
            mqttClient!.publish(self.pubPath, withString: "7" + "2")
        case "Clouds":
            mqttClient!.publish(self.pubPath, withString: "7" + "2")
        default:
            mqttClient!.publish(self.pubPath, withString: "7" + "1")
        }
    }
    
    @IBAction func publishHome(_ sender: Any) {
        mqttClient!.publish(self.pubPath, withString: "0" + "0")
    }
    
    @IBAction func publishWeather(_ sender: Any) {
        self.publishWeatherHelper()
    }
    
    @IBAction func publishSchedule(_ sender: Any) {
        if self.todayEvent != nil {
            print(todayEvent!)
            self.mqttClient!.publish(self.pubPath, withString: "4")
        }
    }
    
    @IBAction func publishMusic(_ sender: Any) {
        mqttClient!.publish(self.pubPath, withString: "5")
    }
    
    @IBAction func publishTemp(_ sender: Any) {
        self.mqttClient!.publish(self.pubPath, withString: "6" + self.temperature!)
    }
    
    @IBAction func microphoneTapped(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            micBtn.isEnabled = false
            if let text = textView.text {
                getIntent(text: text)
            }
            micBtn.setTitle("Start Recording", for: .normal)
        } else {
            startRecording()
            micBtn.setTitle("Stop Recording", for: .normal)
        }
    }
}


