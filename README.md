# Monitoring with Prometheus 

### Configure your AWS from your terminal
    aws configure    #enter your access key id & secret access key 
    aws ec2 describe-instances        # test you can access your aws account 

### install EKS for MAC
    brew tap weaveworks/tap
    brew install weaveworks/tap/eksctl

### Deploy MS in EKS
    eksctl create cluster        # it will create cluster with 2 worker nodes 
    kubectl get node            # to see the nodes that created on aws 
    vim config-microservices.yaml     # makesure that you have all required microservices that needed to be deployed
    kubectl apply -f config-microservices.yaml     # deploy all microservices in the cluster
    kubectl get pod     #makesure that all of your services is up and running in the default namespace 
    
### Install Helm for mac
    brew install helm
    
### Deploy Prometheus Operator Stack using helm
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update       
    kubectl create namespace monitoring     # install prometheus stack into own namespace called monitoring
    helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
    kubectl get all -n monitoring
    
### what's the components inside prometheus , alertmanager, operator  
    kubectl describe statefulset prometheus-monitoring-kube-prometheus-prometheus  -n monitoring > prom.yaml 
    code prom.yaml 
    - you have 2 containers 1 is the main container which is prometheus and config-reloader 
        for prometheus container , you can see what its image and its version , the port they running at ? , for Mounts: where the prometheus gets its configuration data
                for ex: crets , config file define what endpoints to scrape so it has all the add of the apps that expose /metrics 
                    prometheus and all of these data are mounted into prometheus pod  so the satful has access to that pod ,
                rules file define inside it different rules like alerting rules ex: when something happen in the server then send this mail to developer
    for config-reloader which is reposible for reloding the prometheus , when the configuration files are changed , like when you add new target so it will reload the prom 
        هي خالي بالك انت عملت changes جديده فاعملي reload ll prometheus 
        in Init Containers especially "init-config-reloader" 
                if you see the args you will see how config reloader talk to prometheus at prom endpoints "reload-url" 
                also we are telling config-reloader which configs file should to watch for any updates 
                also check the image the config-reloader is using 

    also you may be asking where's the configuration files and rules files comes from ?
            - you have the default configuration files and default rules file that comes when you deploy the prometheus 
             you can see where it mounts for examble: 
                    Mounts:
                          /etc/prometheus/config from config (rw)        # you will see the path of where it comes from "look at volumes under it to see that it comes from the
                                                                                    secret that called prometheus-monitoring-kube-prometheus-prometheus"
            kubectl get secret -n monitoring 
            kubectl get secret  -n monitoring  prometheus-monitoring-kube-prometheus-prometheus -o yaml  > secret.yaml

        for rules file , yu can see  where it comes from it mounted "it comes from this cm prometheus-monitoring-kube-prometheus-prometheus-rulefiles-0 that define in volumes"
            kubectl get cm -n monitoring prometheus-monitoring-kube-prometheus-prometheus-rulefiles-0 
             kubectl get cm  -n monitoring  prometheus-monitoring-kube-prometheus-prometheus -o yaml  > rules.yaml    # and you can see some of different rules are defines 


    kubectl describe statefulset alertmanager-monitoring-kube-prometheus-alertmanager -n monitoring > alert.yaml
        - you can see the main container which is alertmanager

    kubectl get deployment -n monitoring 
    kubectl describe deployment monitoring-kube-prometheus-operator -n monitoring  > opera.yaml 
        it will orchestrate all of prometheus stack , and how every thing is work and how it connected with each other 

[Link to the chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack]

### what is our goal ? 
    - we want to notice when something unexpected happens 
    - observe or monitor cpu spikes , insufficient storage , high load , unauthorized requests 
            ex: if I need to monitor cluster nodes (cpu , ram) , applications ? number of requests , k8s components ? app availability 
    - analyze that and take an action 


### Access Prometheus UI
    kubectl get svc -n monitoring         "monitoring-kube-prometheus-prometheus"
    kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &        #copy the ip:port that appeared ex: 127.0.0.1:9090
            then ask you self "what targets is prometheus monitoring? "    >> Prometheus UI >> status >> targets >> you can see a list of targets that Prometheus collecting 
            data from , and that means if you need to add a new target it should be appeared also here 
            Also if you need to see its metrics from >> Prometheus UI >> write in search what metrics you need to observe like cpu of container and so on 

### Access Grafana
    kubectl get svc -n monitoring 
    kubectl port-forward svc/monitoring-grafana 8080:80 -n monitoring &
        user: admin
        pwd: prom-operator
   try to have a look at each component and targets and other metrics like nodes , clusters , and so on 


### Trigger CPU spike with many requests (Optional)
    - execute a simple script that hits the endpoint of our application we will make it to send 10000 request to our application we will supposed to see some of spikes in cpu 
    - you frontend application that supposed to be hitted is "frontend"
      kubectl get svc     # look at "frontend" and its endpoint which it's endpoint
      
   So I will try to Deploy a busybox pod , with an image that execute curl command so we can curl our application 
    - kubectl run curl-test --image=radial/busyboxplus:curl -i --tty --rm
    - inside your busybox container create a simple script that hit your application 
        [ root@curl-test:/ ]$ vi test.sh                          
        create a script which curls the application endpoint. The endpoint is the external loadbalancer service endpoint
        for i in $(seq 1 10000)
        do
          curl ae4aee0715edc46b988c6ce67121bf57-1459479566.eu-west-3.elb.amazonaws.com > test.txt
        done

        chmod    +x    test.sh


### Alerting with Prometheus 
    - Define what we want to be notified about ex: send notification, when pod can't restart 
    - Send Notification (Configure Aler Manager) , to send mails or slack notifications

    From Prometheus Ui >> Alerts >> you can see already configured alerts that gouped by a name , so you have group called alertmanager.rule , Kubernetes-apps that very 
        important for us as inside each it  you will find some alert rules for k8s resources pods , deployments and so on , and that mean when the you will be triggered 
                when the alert happens 

        for first alert you will find that , 
                name: name of alert 
                expression : written in promqul lang(if this and this are equal what ever then fire alert) the same logic : if failed manager failed to reload then fire the alert
                saverity : the importance of alert is critical , warning and based on that you send to slack or mail 
                annotions : some of info about the alert and how to receive it

        Green color: condition not met , inactive
        red color : firing , condition is met 

### Creat your own alert 
    - create a yaml file called "alert-rules.yaml" for checking the cpu load on the node 
    - take a copy 1st alert from your alerts in prometheus ui and change that 
        1- name: HostHighCpuLoad
        2- expr: you need to search from the metrics about the metrics of "node_cpu_seconds_total" and get its expr , you will find different modes so search about mode=idle
                            which means that cpu is not being used so that tell us "node_cpu_seconds_total{mode="idle"}" how much the cpu are idle ,
                            so we want to see ifnthe average idle time of cpu per node > 50% so fire the alert 
           expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 50
'''  
name: AlertmanagerFailedReload    
expr: max_over_time(alertmanager_config_last_reload_successful{job="monitoring-kube-prometheus-alertmanager",namespace="monitoring"}[5m]) == 0    
for: 10m
labels:
    severity: critical
annotations:
    description: Configuration has failed to load for {{ $labels.namespace }}/{{ $labels.pod}}.
    runbook_url: https://runbooks.prometheus-operator.dev/runbooks/alertmanager/alertmanagerfailedreload
    summary: Reloading an Alertmanager configuration has failed.
'''        

### TO BE 

'''
name: HostHighCpuLoad
expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 50
for: 2m
labels:
  severity: warning
  namespace: monitoring
annotations:
  description: "CPU load on host is over 50%\n Value = {{ $value }}\n Instance = {{ $labels.instance }}\n"
  runbook_url: https://runbooks.prometheus-operator.dev/runbooks/alertmanager/alertmanagerfailedreload
  summary: "Host CPU load high"

'''

### How to add this alert :
    - if you r going to prometheus ui >> configuration >> rule-files  "you will see the file that include all the alert rulesas this file is where all the rules are defines
        and as we are running prometheus as on operator so we can't modify this file and add our rule , and the alternative way to add your rule is to add custom k8s component
            which r defined by crds to create alert rules , so that operator tell prometheus at that case hey you have a new rule please take it 
    - So we will create custome k8s resource to add our new rule , search how to do that "prometheus operator monitoring.coreos.com/v1 "
    - Also we will create another alert that alert whenever the pods can't bet starting , or crashlooping status
        and this metrics that we will use for this  kube_pod_container_status_restarts_total > 5 >> tell us how many time the container will restart with this value 5 then 
            fire alert
    
'''
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: main-rules
  namespace: monitoring
  labels:
    app: kube-prometheus-stack 
    release: monitoring
spec:
  groups:
  - name: main.rules
    rules:
    - alert: HostHighCpuLoad
      expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 50
      for: 2m
      labels:
        severity: warning
        namespace: monitoring
      annotations:
        description: "CPU load on host is over 50%\n Value = {{ $value }}\n Instance = {{ $labels.instance }}\n"
        summary: "Host CPU load high"
    - alert: KubernetesPodCrashLooping
      expr: kube_pod_container_status_restarts_total > 5
      for: 0m
      labels:
        severity: critical
        namespace: monitoring
      annotations: 
        description: "Pod {{ $labels.pod }} is crash looping\n Value = {{ $value }}"
        summary: "Kubernetes pod crash looping"

'''
    
### Apply this alert rules
    - as we define the name space in alert-rule file which monitoring , then you don't need to identify it again when your r running 
        #kubectl apply -f alert-rules.yaml 

        list your all reuels you have 
        #kubectl get PrometheusRule -n monitoring     >> you will find you custom rule that you define which is "main-rules"

        So we expect that prometheus operator which is activly listening for any new resources like what we did inside the cluster , and tell prometheus hey you have a new rule
                so the container of "config-reloader" will reload the prometheus to puckip these changes , and to makesure that this is happened
                #kubectl get pod  -n monitoring          "prometheus-monitoring-kube-prometheus-prometheus-0"
                #kubectl logs prometheus-monitoring-kube-prometheus-prometheus-0 -n monitoring  -c config-reloader
                    you will see logs that msg="Reload triggered" at a now of today "ts=2023-09-24"
   
    - Now if you you are going to prometheus ui >> alerts >> you will find your new alert 

### Test Alert Rules
    - we will simulate a cpu load on the cluster to trigger this alert 
    - Go to GrafaUi >> specify the metrics of Kubernetes >> compute resources >> cluster >> you can see the cpu load of your cluster 
    - So we will deploy an application that load our cluster >> from dockerhub >> search about image called "cpustress" 
        #kubectl run cpu-test --image=containerstack/cpustress -- --cpu 4 --timeout 30s --metrics-brief 
        #kubectl get pod
    - open you Grafana and see that the load on your cpu is loaded , also if you open your alerts on prometheus , you can see that your alert pending that means
        tht the value of cpu on specific instance is 82% , and now it waiting for 2 min in a pending state until it acrually fire the alert , so if this issue isn't get sloveed 
                in 2 min "it should become below 50%" then the alert will become fire state , if you refresh again the state back to "green" state cpu load down again after the
                    alert was fired

    Note that :
            Firing state means that : prometheus will send the alert to alertmanager that will recive that alert and send notification or mail
            so we wanna to access the alertmanager
        
### Access Alert manager UI
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093 &

    - From  Alert manager UI >> status >> you can see the default configuration that alert manager is currently work on , that consists of 3 main components 
            receivers: it will be notification channel like: mail , slack channel 
            route: which alert should be sent to which receiver 
            global: global varibles that apply for that whole configurations
            
    - Note that :
            - you can't edit or adjust your alert manager that are deployed in cluster but you can add you custom resource component  ,as the same for prometheus alert rules    
                so if you search about custom resource for alertmanager "prometheus operator monitoring.coreos.com/v1" then search about "Alertmanager" then create your 
                alert manager 


### Create Alert Manager 
       1- create a secret yaml file for your password as you can't add it hardcoded directly , and make sure that the secret are in the same namespace with alert manager

'''
apiVersion: v1
kind: Secret
type: Opaque
metadata: 
  name: gmail-auth
  namespace: monitoring
data:
  password: < your encoded password>

'''
    
       2- Create your aler manager 
       vim alert-manager-configuration.yaml

'''

apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: main-rules-alert-config
  namespace: monitoring
spec:
  route:
    receiver: 'email'
    repeatInterval: 30m
    routes:
    - matchers:
      - name: alertname
        value: HostHighCpuLoad
    - matchers:
      - name: alertname
        value: KubernetesPodCrashLooping
      repeatInterval: 10m
  receivers:
  - name: 'email'
    emailConfigs:
    - to: 'moh.eltonopy@gmail.come'
      from: 'moh.eltonopy@gmail.come'
      smarthost: 'smtp.gmail.com:587'
      authUsername: 'moh.eltonopy@gmail.come'
      authIdentity: 'moh.eltonopy@gmail.come'
      authPassword:
       name: gmail-auth
       key: password
            
'''

    3- Apply the configuration 
        kubectl apply -f email-secret.yaml
        kubectl apply -f alert-manager-configuration.yaml 
        kubectl get alertmanagerconfig -n monitoring     "new alert manager is created"
        kubectl get pod  -n monitoring     "alertmanager-monitoring-kube-prometheus-alertmanager-0 "
        kubectl logs alertmanager-monitoring-kube-prometheus-alertmanager-0  -n monitoring -c config-reloader        "the reloader are triggered today"

        - open your AlertManager Ui >> status >> you can see the alert manager 

    4- Test the changes 
        - as our alerts is green now so we will load the cpu again by deleting cpu-test pod and create it again
            kubectl get pod 
            kubectl delete pod cpu-test

        - Create cpu stress
            kubectl run cpu-test --image=containerstack/cpustress -- --cpu 4 --timeout 60s --metrics-brief

        - then check from alerts in prometheus that the state is pending then became firing 
        - if you didn't receive any mail so you can check that from the logs of alertmanager 
            kubectl logs alertmanager-monitoring-kube-prometheus-alertmanager-0  -n monitoring -c alertmanager

### Deploy Redis Exporter
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add stable https://charts.helm.sh/stable
    helm repo update

    helm install redis-exporter prometheus-community/prometheus-redis-exporter -f redis-values.yaml
