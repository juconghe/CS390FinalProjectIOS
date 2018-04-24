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

class ViewController: UIViewController {
    let host = "io.adafruit.com"
    let username = "Jucong"
    let pass = "01a85723468e409bb15488a77efe724c"
    let sliderPath = "Jucong/feeds/valueslider"
    let pubPath = "Jucong/feeds/publish"
    let calPath = "Jucong/feeds/caldendar"
    
    let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    
    let player = MPMusicPlayerController.systemMusicPlayer()
    let eventStore = EKEventStore()
    
    var todayEvent: String?
    
    var mqttClient: CocoaMQTT?

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
                self.mqttClient!.publish(self.pubPath, withString: "welcome")
            case "home":
                self.speak(text: response.result.fulfillment.speech)
                self.mqttClient!.publish(self.pubPath, withString: "home")
            case "schedule":
                if self.todayEvent != nil {
                    self.speak(text: response.result.fulfillment.speech)
                    self.mqttClient!.publish(self.calPath, withString: self.todayEvent!)
                }
            case "weather_info":
                self.speak(text: response.result.fulfillment.speech)
                self.mqttClient!.publish(self.pubPath, withString: "weather")
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
    
    @IBAction func publishHome(_ sender: Any) {
        mqttClient!.publish(self.pubPath, withString: "0")
    }
    @IBAction func publishWeather(_ sender: Any) {
        mqttClient!.publish(self.pubPath, withString: "1")
    }
    @IBAction func publishSchedule(_ sender: Any) {
        if self.todayEvent != nil {
            self.mqttClient!.publish(self.calPath, withString: self.todayEvent!)
        }
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


