# Build the Docker image and push it to DockerHub

We want to concentrate ourselves on kubernetes more than on the application. As such, we will create a very simple Docker image based on Nginx which displays an HTML page showing the hostname of the container/pod and with a background color corresponding to a variable: HTML_COLOR (default color will be white). All the details are provided in the Dockerfile.

### Build new image

    docker image build -t color-app:v1 .

### Check the newly created image

    docker image ls color-app

### Launch the image as a standalone container exposed on port 80

    docker container run -d -p 80:80 --name color-app color-app:v1
    
    # Check the HTML output
    curl http://localhost:80/
    
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset=utf-8 />
        <title>white</title>
        <style>
          body {
            background-color: white;
          }
        </style>
      </head>
        <body>
            <div style=text-align:center>
              082f7627d71b
            </div>
        </body>
    </html>



### Launch the image overriding the default background color

    docker container run -d -p 80:80 --name color-app -e HTML_COLOR=blue color-app:v1
    
    # Check the HTML output
    curl http://localhost:80/
    
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset=utf-8 />
        <title>blue</title>
        <style>
          body {
            background-color: blue;
          }
        </style>
      </head>
        <body>
            <div style=text-align:center>
              9bc86e325288
            </div>
        </body>
    </html>



### Push the image to dockerhub

    docker tag color-app:v1 <registry>/color-app:v1
    docker login
    docker push <registry>/color-app:v1

For instance : 

I will replace \<registry\> with my Docker ID 'zigouigoui' if I want my image to be pushed to the root of my registry.

My image will then be accessible here : https://hub.docker.com/repository/docker/zigouigoui/color-app

