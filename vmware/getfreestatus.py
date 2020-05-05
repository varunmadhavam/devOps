import re
import sys
import requests
import json
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

initial_margin=10 #Free space to be available in datastore for backup in %
scale=5 #The scale factor by which the free space of 10% to be incremented in case of multiple VMs in the same datastore in %.
        #Margin = initial_margin + ((no of vms in datatore)-1)*scale
debug=True #verbose output usefull for debugging
vcenter_user="******"
vcenter_pass="******"
vcenter_ip="********"
vcenter_auth_url="https://"+vcenter_ip+"/rest/com/vmware/cis/session"
vmsurl='https://'+vcenter_ip+'/rest/vcenter/vm'
datastoreurl='https://'+vcenter_ip+'/rest/vcenter/datastore'

def prRed(skk): print("\033[91m{}\033[00m".format(skk))
def prGreen(skk): print("\033[92m{}\033[00m".format(skk))

if len(sys.argv) < 2:
        prRed("Require atleast one VM name")
        prRed("Usage python getfreestatus.py VMNAME1 VMNAME2 ..")
        exit(1)

s=requests.Session()
s.verify=False

#Get VM Details
auth=s.post(vcenter_auth_url,auth=(vcenter_user,vcenter_pass))
if auth.status_code != 200 :
        if debug:
                prRed("Failed to authenticate to vcenter server")
        exit(1)
i=1
while i < len(sys.argv):
        if i == 1:
                vmsurl+='?filter.names.'+str(i)+'='+sys.argv[i]
        else:
                vmsurl+='&filter.names.'+str(i)+'='+sys.argv[i]
        i+=1
vms=s.get(vmsurl)
if vms.status_code != 200 :
        if debug:
                prRed("Failed to get list of VMs from vcenter server")
        exit(1)
vms=json.loads(vms.text)["value"]
if len(vms) != len(sys.argv)-1:
        if debug:
                prRed("Mismath in the number of command line params and the VMs returned. Please check VM names")
        exit(1)

#Get Datastores of All VMs
datastores=[]
for vm in vms:
    vmurl='https://'+vcenter_ip+'/rest/vcenter/vm/'+vm.get("vm")
    vmdata=s.get(vmurl)
    if vmdata.status_code != 200:
        if debug:
                prRed("Failed to get  VMs details from vcenter server")
        exit(1)
    disks=json.loads(vmdata.text)["value"].get("disks")
    tmp=[]
    for disk in disks:
        diskname = disk["value"]["backing"]["vmdk_file"]
        datastore = diskname[diskname.find("[")+1 : diskname.find("]")]
        tmp.append(str(datastore))
    datastores+=list(set(tmp))

datastoresdict=dict()
for datastore in datastores:
        if datastore in datastoresdict:
                datastoresdict[datastore] += 1
        else:
                datastoresdict[datastore]  = 1

i=0
for datastore, frequency in datastoresdict.items():
        if i == 0:
                datastoreurl+='?filter.names.'+str((i+1))+'='+datastore
        else:
                datastoreurl+="&filter.names."+str((i+1))+'='+datastore
        i+=1

#Get space utilisation of datastores and check if witin limits
datastores=s.get(datastoreurl)
datastores=json.loads(datastores.text)["value"]
error=0
for datastore in datastores:
        free=(float(datastore.get("free_space"))/datastore.get("capacity"))*100
        margin=initial_margin + ((datastoresdict[datastore.get("name")]-1)*scale)
        if free < margin :
                if debug:
                        prRed("free space check failed for datastore "+datastore.get("name")+" ; free : "+str(free)+"%"+" margin : "+str(margin)+"%")
                        error=1
                else:
                        error=1
                        break
        else:
                if debug:
                        prGreen("free space check succedded for datastore "+datastore.get("name")+" ; free : "+str(free)+"%"+" margin : "+str(margin)+"%")
exit(error)
