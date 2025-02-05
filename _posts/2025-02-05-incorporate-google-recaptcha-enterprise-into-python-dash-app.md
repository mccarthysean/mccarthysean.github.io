---
layout: post
title: 'Use Google reCAPTCHA Enterprise v3 (invisible) in Plotly Dash app'
tags: [Python, Dash, reCAPTCHA]
featured_image_thumbnail:
# featured_image: assets/images/posts/2021/timescaledb-logo2.png
featured: false
hidden: false
---

The purpose of this is to show how to incorporate Google's reCAPTCHA Enterprise v3 (invisible) assessment score into a Python-based Dash application.

Inspiration from this [Plotly Dash community post](https://community.plotly.com/t/integrating-googles-recaptcha-with-dash/57851).

JavaScript to put into Dash's "assets" folder:

```javascript
// Global variable to track reCAPTCHA state
window.recaptchaState = {
  loaded: false,
  siteKey: null,
  action: null,
  initialized: false,
};

// Function to initialize invisible reCAPTCHA
async function initializeRecaptcha(data) {
  // Store siteKey and action globally
  window.recaptchaState.siteKey = data["site_key"];
  window.recaptchaState.action = data["action"];

  // Load reCAPTCHA script if not already loaded
  if (!window.recaptchaState.loaded) {
    await new Promise((resolve, reject) => {
      console.log("Loading reCAPTCHA script...");
      const script = document.createElement("script");
      // If the following doesn't render properly (i.e. the MIME type is set to HTML instead of JS)
      // then make a new site key using reCAPTCHA v3 (invisible and score-based instead of render-based and clickable)
      // Here's the error message if the link below doesn't work properly:
      //    ERROR: The resource from "https://www.google.com/recaptcha/enterprise.js?render=..."
      //    was blocked due to MIME type ("text/html") mismatch (X-Content-Type-Options: nosniff
      script.src = `https://www.google.com/recaptcha/enterprise.js?render=${window.recaptchaState.siteKey}`;
      // script.async = true;
      // script.defer = true;
      // Ensure the correct MIME type is set so the browser doesn't think it's an HTML file
      script.type = "text/javascript";

      script.onload = async () => {
        console.log("reCAPTCHA script loaded successfully");
        window.recaptchaState.loaded = true; // Mark as loaded
        resolve();
      };

      // Handle script load error
      script.onerror = (error) => {
        reject(new Error("Failed to load reCAPTCHA script"));
      };

      // Put the script in the head tag
      document.head.appendChild(script);
    });
  }

  // Initialize after loading
  if (!window.recaptchaState.initialized) {
    try {
      // Wrap grecaptcha.enterprise.ready() in a Promise
      await new Promise((resolve, reject) => {
        window.grecaptcha.enterprise.ready(() => {
          console.log("reCAPTCHA is ready");
          window.recaptchaState.initialized = true;
          resolve();
        });
      });
    } catch (error) {
      console.error("reCAPTCHA initialization error:", error);
      throw error;
    }
  }

  // This is just the children of the div, not the div itself
  return "";
}

// Handle form submission and reCAPTCHA verification
async function handleFormSubmit(n_clicks, data) {
  try {
    // if (!window.recaptchaState.loaded || !window.grecaptcha?.enterprise) {
    if (!window.grecaptcha?.enterprise) {
      throw new Error("reCAPTCHA not loaded yet");
    }

    // Wait for reCAPTCHA to be ready
    await new Promise((resolve, reject) => {
      window.grecaptcha.enterprise.ready(() => {
        console.log("reCAPTCHA is ready");
        resolve();
      });
    });

    // Execute invisible reCAPTCHA
    const token = await window.grecaptcha.enterprise.execute(data["site_key"], {
      action: data["action"],
    });

    console.log("reCAPTCHA token:", token);
    return token; // Return the token to the caller
  } catch (error) {
    console.error("reCAPTCHA error:", error);
    throw error;
  }
}

// Expose functions to Dash clientside callbacks
window.dash_clientside = Object.assign({}, window.dash_clientside, {
  contact_namespace: {
    initialize_recaptcha_in_js: initializeRecaptcha,
    on_submit_application: handleFormSubmit,
  },
});
```

Contact page layout in Dash:

```python
import os
from typing import List

import dash_bootstrap_components as dbc
import phonenumbers
from dash import (
    ClientsideFunction,
    Input,
    Output,
    State,
    callback,
    clientside_callback,
    dcc,
    html,
)
from dash.exceptions import PreventUpdate
from flask_login import current_user


def contact_layout():
    """Get the Dash layout for the contact page."""
    return dbc.Container(
        dbc.Row(
            justify="center",
            children=dbc.Col(
                lg=10,
                xl=8,
                # xxl=6,
                # fluid=True,
                children=[
                    # Hidden signal value, which starts the page-load callbacks
                    html.Div(id="hidden_signal_contact", style=DISPLAY_NONE),
                    # Store something neeeded for dynamic JavaScript (e.g. Google RECAPTCHA site key)
                    dcc.Store(
                        id="store_site_key_action_contact", storage_type="memory"
                    ),
                    # Need a dummy place for an Output() to nowhere
                    dcc.Store(id="store_nothing_contact", storage_type="memory"),
                    # Store the reCAPTCHA response so we can assess it in the callback
                    dcc.Store(
                        id="store_recaptcha_response_contact", storage_type="memory"
                    ),

                    dbc.Card(
                        class_name="mt-3",
                        children=[
                            dbc.CardHeader(
                                "Contact IJACK",
                            ),
                            dbc.CardBody(
                                [
                                    dbc.Row(
                                        [
                                            dbc.Col(
                                                [
                                                    dbc.Label(
                                                        "First Name",
                                                        html_for="contact_first_name",
                                                        class_name="mb-1",
                                                    ),
                                                    dbc.Input(
                                                        type="text",
                                                        id="contact_first_name",
                                                        persistence=True,
                                                    ),
                                                ]
                                            ),
                                            dbc.Col(
                                                [
                                                    dbc.Label(
                                                        "Last Name",
                                                        html_for="contact_last_name",
                                                        class_name="mb-1",
                                                    ),
                                                    dbc.Input(
                                                        type="text",
                                                        id="contact_last_name",
                                                        persistence=True,
                                                    ),
                                                ]
                                            ),
                                        ],
                                        class_name="mb-3",
                                    ),
                                    dbc.Row(
                                        [
                                            dbc.Col(
                                                [
                                                    dbc.Label(
                                                        "Email",
                                                        html_for="contact_email",
                                                        class_name="mb-1",
                                                    ),
                                                    dbc.Input(
                                                        type="email",
                                                        id="contact_email",
                                                        persistence=True,
                                                    ),
                                                ]
                                            ),
                                        ],
                                        class_name="mb-3",
                                    ),
                                    dbc.Row(
                                        [
                                            dbc.Col(
                                                [
                                                    dbc.Label(
                                                        "Message",
                                                        html_for="contact_message",
                                                        class_name="mb-1",
                                                    ),
                                                    dbc.Textarea(
                                                        id="contact_message",
                                                        persistence=True,
                                                        # class_name="mb-3",
                                                        placeholder="Enter your message here",
                                                    ),
                                                ]
                                            ),
                                        ],
                                        class_name="mb-4",
                                    ),
                                    
                                    dbc.Row(
                                        dbc.Col(
                                            dbc.Button(
                                                "Submit",
                                                id="contact_submit_btn",
                                                color="dark",
                                                class_name="mr-1",
                                            ),
                                        ),
                                        class_name="mb-1",
                                    ),
                                    dbc.Row(
                                        dbc.Col(
                                            dbc.FormText(
                                                id="contact_submit_status",
                                            )
                                        ),
                                        class_name="mb-1",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
        )
    )
```

The callbacks for storing and processing reCAPTCHA stuff:

```python
from app.recaptcha import recaptcha, RecaptchaResponse


@callback(
    Output("store_site_key_action_contact", "data"),
    Input("hidden_signal_contact", "children"),
    prevent_initial_call=False,
)
def store_google_recaptcha_sitekey(_):
    """Store the reCAPTCHA sitekey in the hidden div"""
    return {"site_key": os.getenv("RECAPTCHA_SITE_KEY", ""), "action": "contact"}


# The following clientside_callbacks refer to JavaScript functions in app/assets/recaptcha.js
clientside_callback(
    ClientsideFunction(
        namespace="contact_namespace",
        function_name="initialize_recaptcha_in_js",
    ),
    Output("store_nothing_contact", "data"),
    Input("store_site_key_action_contact", "data"),
    prevent_initial_call=True,
)

clientside_callback(
    ClientsideFunction(
        namespace="contact_namespace",
        function_name="on_submit_application",
    ),
    Output("store_recaptcha_response_contact", "data"),
    Input("contact_submit_btn", "n_clicks"),
    State("store_site_key_action_contact", "data"),
    prevent_initial_call=True,
)


def recaptcha_is_good(recaptcha_clientside_response: str, expected_action: str) -> bool:
    """For Dash, get the recaptcha response from the client side"""

    if (
        recaptcha_clientside_response is None
        or str(recaptcha_clientside_response).strip() == ""
    ):
        return False

    try:
        result: RecaptchaResponse = recaptcha.verify_token(
            token=recaptcha_clientside_response, expected_action=expected_action
        )
        current_app.logger.info(f"Recaptcha result: {result}")
        return result.success
    except Exception:
        current_app.logger.exception("Problem with recaptcha response")
        return False


@callback(
    Output("contact_submit_status", "children"),
    Output("contact_submit_status", "color"),
    # Input("contact_submit_btn", "n_clicks"),
    Input("store_recaptcha_response_contact", "data"),
    State("contact_first_name", "value"),
    State("contact_last_name", "value"),
    State("contact_email", "value"),
    State("contact_message", "value"),
    # Validation results
    State("contact_first_name", "invalid"),
    State("contact_last_name", "invalid"),
    State("contact_email", "invalid"),
    State("contact_message", "invalid"),
    prevent_initial_call=True,
)
def process_contact_form(
    # contact_submit_btn_n_clicks,
    contact_recaptcha_response_children,
    contact_first_name_value,
    contact_last_name_value,
    contact_email_value,
    contact_message_value,
    # Validation results
    contact_first_name_invalid,
    contact_last_name_invalid,
    contact_email_invalid,
    contact_message_invalid,
):
    """Process the contact form"""

    if (
        # Validation results
        contact_first_name_invalid
        or contact_last_name_invalid
        or contact_email_invalid
        or contact_message_invalid
    ):
        msg = "Please fill in all required fields"
        color = "danger"
        # flash(msg, color)
        return msg, color

    if not recaptcha_is_good(
        contact_recaptcha_response_children, expected_action="contact"
    ):
        msg = "reCAPTCHA verification failed"
        color = "danger"
        # flash(msg, color)
        return msg, color
```

Finally, the "recaptcha.py" module for the server-side assessment generation:

```python
import os
from dataclasses import dataclass
from typing import Optional

from flask import current_app, request
from google.cloud import recaptchaenterprise_v1
from google.oauth2 import service_account


@dataclass
class RecaptchaResponse:
    """Data class to hold reCAPTCHA verification response"""

    success: bool
    score: Optional[float] = None
    action: Optional[str] = None
    error_codes: Optional[list] = None


class RecaptchaEnterprise:
    """Handle Google reCAPTCHA Enterprise verification"""

    def __init__(
        self,
        project_id: str,
        site_key: str,
        credentials_path: str,
    ):
        """Initialize reCAPTCHA Enterprise client

        Args:
            project_id: Google Cloud project ID
            site_key: reCAPTCHA site key
            credentials_dict: Service account JSON dictionary
            credentials_path: Path to service account JSON file
        """
        self.project_id = project_id
        self.site_key = site_key

        if not credentials_path:
            raise ValueError("Service account credentials not provided")

        # Load credentials from service account file
        self.credentials = service_account.Credentials.from_service_account_file(
            credentials_path,
            scopes=["https://www.googleapis.com/auth/cloud-platform"],
        )

    def verify_token(self, token: str, expected_action: str) -> RecaptchaResponse:
        """Verify a reCAPTCHA token

        Args:
            token: The reCAPTCHA token from client
            expected_action: The expected action name to verify

        Returns:
            RecaptchaResponse with verification results
        """
        try:
            # Create the reCAPTCHA client
            client = recaptchaenterprise_v1.RecaptchaEnterpriseServiceClient(
                credentials=self.credentials
            )

            # Create the assessment request
            event = recaptchaenterprise_v1.Event()
            event.site_key = self.site_key
            event.token = token
            event.expected_action = expected_action

            # Add user context if available
            if request:
                event.user_ip_address = request.remote_addr
                event.user_agent = request.headers.get("User-Agent", "")

            # Build the assessment
            assessment = recaptchaenterprise_v1.Assessment()
            assessment.event = event

            # Submit the assessment
            request_obj = recaptchaenterprise_v1.CreateAssessmentRequest()
            request_obj.assessment = assessment
            request_obj.parent = f"projects/{self.project_id}"

            response = client.create_assessment(request_obj)

            # Validate the response
            if not response.token_properties.valid:
                current_app.logger.error(
                    f"Invalid token: {response.token_properties.invalid_reason}"
                )
                return RecaptchaResponse(
                    success=False,
                    error_codes=[str(response.token_properties.invalid_reason)],
                )

            # Verify action matches
            if response.token_properties.action != expected_action:
                current_app.logger.error(
                    f"Action mismatch. Expected: {expected_action}, "
                    f"Got: {response.token_properties.action}"
                )
                return RecaptchaResponse(success=False, error_codes=["action_mismatch"])

            # Return successful response with score
            return RecaptchaResponse(
                success=True,
                score=response.risk_analysis.score,
                action=response.token_properties.action,
            )

        except Exception as e:
            current_app.logger.exception("reCAPTCHA verification failed")
            return RecaptchaResponse(success=False, error_codes=[str(e)])


# Initialize the global reCAPTCHA instance
recaptcha = RecaptchaEnterprise(
    # This should be your Google Cloud project ID, not the reCAPTCHA site key
    # project_id=os.getenv("RECAPTCHA_SITE_KEY"),
    project_id="my-project",
    # This is your reCAPTCHA site key
    site_key=os.getenv("RECAPTCHA_SITE_KEY"),
    credentials_path=os.getenv("GOOGLE_APPLICATION_CREDENTIALS"),
)
```

I hope this saves you a little bit of frustration trying to figure out how to add reCAPTCHA Enterprise in your Plotly Dash application.

Cheers, <br>
Sean
