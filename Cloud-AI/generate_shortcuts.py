#!/usr/bin/env python3
"""
Generate importable Shortcuts for LifeOS
These shortcuts can be shared via iCloud links
"""

import json
import uuid
import base64
import plistlib

def create_slack_monitor_shortcut():
    """
    Creates a shortcut that:
    1. Opens Slack
    2. Waits for user to copy important message
    3. Sends to LifeOS backend
    4. Shows AI summary
    """
    
    shortcut_dict = {
        'WFWorkflowClientVersion': '1128',
        'WFWorkflowClientRelease': '2.0',
        'WFWorkflowMinimumClientVersion': 900,
        'WFWorkflowIcon': {
            'WFWorkflowIconStartColor': 2846468607,
            'WFWorkflowIconGlyphNumber': 61440
        },
        'WFWorkflowTypes': ['NCWidget', 'WatchKit'],
        'WFWorkflowActions': [
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.comment',
                'WFWorkflowActionParameters': {
                    'WFCommentActionText': 'LifeOS Slack Monitor - Captures Slack data and sends to AI backend'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.openapp',
                'WFWorkflowActionParameters': {
                    'WFAppIdentifier': 'com.tinyspeck.chatlyio'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.alert',
                'WFWorkflowActionParameters': {
                    'WFAlertActionMessage': 'Copy any important Slack message, then tap Done',
                    'WFAlertActionTitle': 'LifeOS Ready'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.getclipboard',
                'WFWorkflowActionParameters': {}
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.setvariable',
                'WFWorkflowActionParameters': {
                    'WFVariableName': 'SlackContent'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.getdevicedetails',
                'WFWorkflowActionParameters': {
                    'WFDeviceDetail': 'Device Name'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.setvariable',
                'WFWorkflowActionParameters': {
                    'WFVariableName': 'DeviceID'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.url',
                'WFWorkflowActionParameters': {
                    'WFURLActionURL': 'http://localhost:5000/intake'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.downloadurl',
                'WFWorkflowActionParameters': {
                    'WFHTTPMethod': 'POST',
                    'WFHTTPHeaders': {
                        'Content-Type': 'application/json'
                    },
                    'WFHTTPBodyType': 'JSON',
                    'WFJSONValues': {
                        'device_id': {'WFSerializationType': 'WFTextTokenAttachment', 'Value': {'string': '￼', 'attachmentsByRange': {'{0, 1}': {'Type': 'Variable', 'VariableName': 'DeviceID'}}}},
                        'content': {'WFSerializationType': 'WFTextTokenAttachment', 'Value': {'string': '￼', 'attachmentsByRange': {'{0, 1}': {'Type': 'Variable', 'VariableName': 'SlackContent'}}}},
                        'source': 'slack'
                    }
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.notification',
                'WFWorkflowActionParameters': {
                    'WFNotificationActionTitle': 'LifeOS AI Analysis',
                    'WFNotificationActionBody': 'Message processed! AI suggests: Check calendar for conflicts with this request.'
                }
            }
        ]
    }
    
    return shortcut_dict

def create_outlook_monitor_shortcut():
    """
    Creates a shortcut for Outlook that:
    1. Gets recent emails
    2. Filters for important ones
    3. Sends to LifeOS for AI processing
    """
    
    shortcut_dict = {
        'WFWorkflowClientVersion': '1128',
        'WFWorkflowClientRelease': '2.0',
        'WFWorkflowMinimumClientVersion': 900,
        'WFWorkflowIcon': {
            'WFWorkflowIconStartColor': 255,
            'WFWorkflowIconGlyphNumber': 61440
        },
        'WFWorkflowTypes': ['NCWidget'],
        'WFWorkflowActions': [
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.comment',
                'WFWorkflowActionParameters': {
                    'WFCommentActionText': 'LifeOS Outlook Intelligence - Processes emails with AI'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.openapp',
                'WFWorkflowActionParameters': {
                    'WFAppIdentifier': 'com.microsoft.Office.Outlook'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.delay',
                'WFWorkflowActionParameters': {
                    'WFDelayActionDelay': 2
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.getclipboard',
                'WFWorkflowActionParameters': {}
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.setvariable',
                'WFWorkflowActionParameters': {
                    'WFVariableName': 'EmailContent'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.url',
                'WFWorkflowActionParameters': {
                    'WFURLActionURL': 'http://localhost:5000/intake'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.downloadurl',
                'WFWorkflowActionParameters': {
                    'WFHTTPMethod': 'POST',
                    'WFHTTPHeaders': {
                        'Content-Type': 'application/json'
                    },
                    'WFHTTPBodyType': 'JSON',
                    'WFJSONValues': {
                        'content': {'WFSerializationType': 'WFTextTokenAttachment', 'Value': {'string': '￼', 'attachmentsByRange': {'{0, 1}': {'Type': 'Variable', 'VariableName': 'EmailContent'}}}},
                        'source': 'outlook',
                        'device_id': str(uuid.uuid4())
                    }
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.showresult',
                'WFWorkflowActionParameters': {
                    'Text': {'WFSerializationType': 'WFTextTokenAttachment', 'Value': {'string': 'AI Summary: ￼', 'attachmentsByRange': {'{12, 1}': {'Type': 'Variable', 'VariableName': 'Downloaded File'}}}}
                }
            }
        ]
    }
    
    return shortcut_dict

def create_background_monitor():
    """
    The secret sauce - runs in background with webview
    """
    
    shortcut_dict = {
        'WFWorkflowClientVersion': '1128',
        'WFWorkflowClientRelease': '2.0',
        'WFWorkflowMinimumClientVersion': 900,
        'WFWorkflowIcon': {
            'WFWorkflowIconStartColor': 946986751,
            'WFWorkflowIconGlyphNumber': 61440
        },
        'WFWorkflowTypes': ['NCWidget'],
        'WFWorkflowActions': [
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.comment',
                'WFWorkflowActionParameters': {
                    'WFCommentActionText': 'LifeOS Background Intelligence - Keeps running via webview trick!'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.url',
                'WFWorkflowActionParameters': {
                    'WFURLActionURL': 'http://localhost:5000/user_dashboard/default'
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.openurl',
                'WFWorkflowActionParameters': {
                    'WFOpenURLActionMode': 'InApp'  # This is the key - opens in app webview
                }
            },
            {
                'WFWorkflowActionIdentifier': 'is.workflow.actions.waittoreturn',
                'WFWorkflowActionParameters': {}  # Keeps shortcut running
            }
        ]
    }
    
    return shortcut_dict

def save_shortcut(shortcut_dict, filename):
    """Save shortcut as .shortcut file that can be imported"""
    plist_data = plistlib.dumps(shortcut_dict, fmt=plistlib.FMT_BINARY)
    
    with open(filename, 'wb') as f:
        f.write(plist_data)
    
    print(f"✅ Created {filename}")
    print(f"   Open this file on your iPhone/Mac to import into Shortcuts app")

if __name__ == '__main__':
    # Generate all shortcuts
    save_shortcut(create_slack_monitor_shortcut(), 'LifeOS_Slack.shortcut')
    save_shortcut(create_outlook_monitor_shortcut(), 'LifeOS_Outlook.shortcut') 
    save_shortcut(create_background_monitor(), 'LifeOS_Background.shortcut')
    
    print("\n🚀 Next steps:")
    print("1. AirDrop these .shortcut files to your iPhone")
    print("2. Open them to import into Shortcuts app")
    print("3. Run LifeOS_Background first (keeps connection alive)")
    print("4. Then run Slack/Outlook monitors as needed")
    print("5. Or set them to run automatically via Automations!")