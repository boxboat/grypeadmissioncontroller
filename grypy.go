package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"

	"k8s.io/apimachinery/pkg/types"

	"github.com/golang/glog"
	admission "k8s.io/api/admission/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

//grypyServerHandler listen to admission requests and serve responses
type grypyServerHandler struct {
}

func (gs *grypyServerHandler) serve(w http.ResponseWriter, r *http.Request) {
	var body []byte
	if r.Body != nil {
		if data, err := ioutil.ReadAll(r.Body); err == nil {
			body = data
		}
	}
	if len(body) == 0 {
		glog.Error("empty body")
		http.Error(w, "empty body", http.StatusBadRequest)
		return
	}
	glog.Info("Received request")

	if r.URL.Path != "/validate" {
		glog.Error("no validate")
		http.Error(w, "no validate", http.StatusBadRequest)
		return
	}

	arRequest := admission.AdmissionReview{}
	if err := json.Unmarshal(body, &arRequest); err != nil {
		glog.Error("incorrect body")
		http.Error(w, "incorrect body", http.StatusBadRequest)
	}

	pod := v1.Pod{}

	if err := json.Unmarshal(arRequest.Request.Object.Raw, &pod); err != nil {
		glog.Error("error unmarshaling request to pod")
	}

	// grype implementation
	grype := "/usr/local/bin/grype"
	severity := os.Getenv("SEVERITY")
	severity_option := "--fail-on"
	var stdout []byte
	var err error
	var allow bool
	var arResponse *admission.AdmissionResponse

	for _, s := range pod.Spec.Containers {
		cmd := exec.Command(grype, severity_option, severity, s.Image)
		stdout, err = cmd.CombinedOutput()
		if err == nil {
			allow = true
			glog.Info(string(stdout)) //tuck this in our log for later reference
			arResponse = getResponse(allow, fmt.Sprintf("No vulnerabilties found in: %s", s.Image), arRequest.Request.UID)
		}
		if err != nil {
			glog.Infof("\n stdout and stderr = %s \n errorcode = %s \n image = %s \n command = %s %s %s %s", string(stdout), err, s.Image, grype, severity_option, severity, s.Image)
			arResponse = getResponse(allow, fmt.Sprintf("Vulnerabilities were found in %s exceeding severity %s so the container cannot be launched.", s.Image, severity), arRequest.Request.UID)
		}
	}

	kubeResponse := admission.AdmissionReview{
		TypeMeta: metav1.TypeMeta{
			Kind:       "AdmissionReview",
			APIVersion: "admission.k8s.io/v1",
		},
		Request:  arRequest.Request,
		Response: arResponse,
	}

	resp, err := json.Marshal(kubeResponse)
	if err != nil {
		glog.Errorf("Can't encode response: %v", err)
		http.Error(w, fmt.Sprintf("could not encode response: %v", err), http.StatusInternalServerError)
	}
	glog.Infof("Ready to write reponse ... %s", string(stdout))
	if _, err := w.Write(resp); err != nil {
		glog.Errorf("Can't write response: %v", err)
		http.Error(w, fmt.Sprintf("could not write response: %v", err), http.StatusInternalServerError)
	}
}

func getResponse(allow bool, reason string, uid types.UID) *admission.AdmissionResponse {
	code := http.StatusForbidden
	if allow {
		code = http.StatusOK
	}
	return &admission.AdmissionResponse{
		Allowed: allow,
		Result: &metav1.Status{
			Code:   int32(code),
			Reason: metav1.StatusReason(reason),
		},
		UID: uid,
	}
}
