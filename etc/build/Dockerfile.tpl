# Prerequisites:
#   dep ensure --vendor-only

#==============================
# Stage 1: Native Driver Build
#==============================
{{if and (ne .Native.Build.Gopath "") (eq .Native.Build.Image "") -}}
FROM golang:{{ .Runtime.Version }} as native
{{- else -}}
FROM {{ .Native.Build.Image }} as native
{{- end}}

{{- if ne (len .Native.Build.Add) 0}}

# add dependency files
{{range .Native.Build.Add -}}
ADD {{ .Path }} {{ .Dest }}
{{end}}
{{- end}}

{{- if ne (len .Native.Build.Deps) 0}}

# install build dependencies
{{range .Native.Build.Deps -}}
RUN {{ . }}
{{end}}
{{- end}}

{{if ne .Native.Build.Gopath "" -}}
ENV DRIVER_REPO=github.com/bblfsh/{{ .Language }}-driver
ENV DRIVER_REPO_PATH={{ .Native.Build.Gopath }}/src/$DRIVER_REPO

ADD vendor $DRIVER_REPO_PATH/vendor
ADD driver $DRIVER_REPO_PATH/driver
ADD native $DRIVER_REPO_PATH/native
WORKDIR $DRIVER_REPO_PATH/native
{{- else -}}
ADD native /native
WORKDIR /native
{{- end}}

# build native driver
{{range .Native.Build.Run -}}
RUN {{ . }}
{{end}}

#=================================
# Stage 2: Go Driver Server Build
#=================================
FROM golang:{{ .Runtime.Version }} as driver

ENV DRIVER_REPO=github.com/bblfsh/{{ .Language }}-driver
ENV DRIVER_REPO_PATH=/go/src/$DRIVER_REPO

ADD vendor $DRIVER_REPO_PATH/vendor
ADD driver $DRIVER_REPO_PATH/driver
WORKDIR $DRIVER_REPO_PATH/

# build tests
RUN go test -c -o /tmp/fixtures.test ./driver/fixtures/
# build server binary
RUN go build -o /tmp/driver ./driver/main.go

#=======================
# Stage 3: Driver Build
#=======================
FROM {{ .Native.Image }}

LABEL maintainer="source{d}" \
      bblfsh.language="{{ .Language }}"

WORKDIR /opt/driver

# copy driver manifest and static files
ADD manifest.toml ./

{{- if ne (len .Native.Static) 0}}

# copy static files from driver source directory
{{range .Native.Static -}}
ADD ./native/{{ .Path }} ./bin/{{ .Dest }}
{{end}}
{{- end}}

# copy build artifacts for native driver
{{range .Native.Build.Artifacts -}}
COPY --from=native {{ .Path }} ./bin/{{ .Dest }}
{{end}}

# copy tests binary
COPY --from=driver /tmp/fixtures.test ./bin/
# move stuff to make tests work
RUN ln -s /opt/driver ../build
VOLUME /opt/fixtures

# copy driver server binary
COPY --from=driver /tmp/driver ./bin/

ENTRYPOINT ["/opt/driver/bin/driver"]