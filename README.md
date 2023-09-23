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

### Trigger CPU spike with many requests

##### Deploy a busybox pod so we can curl our application 
    kubectl run curl-test --image=radial/busyboxplus:curl -i --tty --rm

##### create a script which curls the application endpoint. The endpoint is the external loadbalancer service endpoint
    for i in $(seq 1 10000)
    do
      curl ae4aee0715edc46b988c6ce67121bf57-1459479566.eu-west-3.elb.amazonaws.com > test.txt
    done


### Access Alert manager UI
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093 &

#### Create cpu stress
    kubectl delete pod cpu-test; kubectl run cpu-test --image=containerstack/cpustress -- --cpu 4 --timeout 60s --metrics-brief


### Deploy Redis Exporter
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add stable https://charts.helm.sh/stable
    helm repo update

    helm install redis-exporter prometheus-community/prometheus-redis-exporter -f redis-values.yaml
