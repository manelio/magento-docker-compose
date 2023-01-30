vcl 4.0;

sub vcl_recv {
    return (pass);
}

backend default {
    .host = "nginx";
    .port = "80";
}
