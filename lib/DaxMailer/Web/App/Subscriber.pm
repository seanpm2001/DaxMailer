package DaxMailer::Web::App::Subscriber;

# ABSTRACT: Subscriber management

use DaxMailer::Base::Web::Common;
use Dancer2::Plugin::Auth::HTTP::Basic::DWIW;
use DaxMailer::Script::SubscriberMailer;
use Email::Valid;

my $subscriber = DaxMailer::Script::SubscriberMailer->new;

http_basic_auth_set_check_handler sub {
    my ( $user, $pass ) = @_;
    return $user eq config->{basic_auth_user} && $pass eq config->{basic_auth_pass};
};

get '/u/:campaign/:email/:key' => sub {
    my $params = params('route');
    my $s = rset('Subscriber')->find( {
        email_address => $params->{email},
        campaign      => $params->{campaign},
    } );
    my $legacy_unsub = rset('Subscriber::Bounce')->legacy_unsub( $params->{email} );
    template 'email/a/unsub.tx',
             { success =>
                 ( ( $s && $s->unsubscribe( $params->{ key } ) ) ||
                 $legacy_unsub > 0 )
             },
             { layout => undef };
};

get '/v/:campaign/:email/:key' => sub {
    my $params = params('route');
    my $s = rset('Subscriber')->find( {
        email_address => $params->{email},
        campaign      => $params->{campaign},
    } );
    template 'email/a/verify.tx',
             { success => (
                     $s && $s->verify( $params->{ key } )
                 )
             },
             { layout => undef };
};

get '/form' => sub {
    return <<'FORM'
    <form method="POST" action="/s/a">
        email: <input type="text" name="email">
        <input type="submit" name="submit">
        <input type="hidden" name="campaign" value="a">
        <input type="hidden" name="flow" value="form">
    </form>
FORM
};

any '/testrun/**' => http_basic_auth required => sub {
    pass;
};

get '/testrun/:campaign' => sub {
    return <<'TESTRUN'
    <form method="POST">
        <h3>Send a test run of all mails</h3>
        email: <input type="text" name="email"><br />
        from: <textarea name="from"></textarea><br />
        <input type="checkbox" name="verify_only" id="verify_only">
        <label for="verify_only">
            Only send verify stage emails
        </label><br />
        <input type="submit" name="submit">
    </form>
TESTRUN
};

post '/testrun/:campaign' => sub {
    my $routeparams = params('route');
    my $bodyparams = params('body');
    my $email = Email::Valid->address($bodyparams->{email});
    return unless $email;
    return unless $email =~ /\@duckduckgo\.com$/;
    my $extra = {};
    $extra->{from} = $bodyparams->{from} if $bodyparams->{from};
    $extra->{verify_only} = $bodyparams->{verify_only};
    DaxMailer::Script::SubscriberMailer->new->testrun(
        $routeparams->{campaign},
        $bodyparams->{email},
        $extra
    );
    return 'OK';
};

post '/a' => sub {
    my $params = params('body');
    if ( !$subscriber->add( $params ) ) {
        status 500;
        return "NOT OK";
    }
    return "OK";
};

1;
