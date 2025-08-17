#!/usr/bin/env python3
"""
LifeOS Prototype - Smart Shortcuts Backend
This demonstrates how to handle different apps/users dynamically
"""

from flask import Flask, request, jsonify
import json
from datetime import datetime
import hashlib

app = Flask(__name__)

# Simulated user profiles and app patterns
USER_CONTEXTS = {}

@app.route('/intake', methods=['POST'])
def intake():
    """
    Universal endpoint that shortcuts call
    AI parses what app/data type and responds accordingly
    """
    data = request.json
    
    # Generate user fingerprint (in prod, would be authenticated)
    user_id = data.get('device_id', 'unknown')
    
    # AI would parse this - for now, simple detection
    app_source = detect_app_source(data)
    content = data.get('content', '')
    metadata = data.get('metadata', {})
    
    # Store context
    if user_id not in USER_CONTEXTS:
        USER_CONTEXTS[user_id] = {
            'apps_detected': set(),
            'patterns': [],
            'last_seen': None
        }
    
    USER_CONTEXTS[user_id]['apps_detected'].add(app_source)
    USER_CONTEXTS[user_id]['last_seen'] = datetime.now().isoformat()
    
    # Generate personalized automation suggestion
    automation = generate_automation(user_id, app_source, content)
    
    return jsonify({
        'status': 'processed',
        'detected_app': app_source,
        'suggested_automation': automation,
        'next_shortcut': generate_next_shortcut(user_id, app_source)
    })

def detect_app_source(data):
    """Detect which app the data came from"""
    content = str(data.get('content', '')).lower()
    source = str(data.get('source', '')).lower()
    
    # Work apps first - this is where the money is
    if 'slack' in source or 'slack' in content:
        return 'slack'
    elif 'teams' in source or 'teams' in content:
        return 'teams'
    elif 'outlook' in source or 'outlook' in content:
        return 'outlook'
    elif 'gmail' in source or 'gmail' in content:
        return 'gmail'
    elif 'notion' in source or 'notion' in content:
        return 'notion'
    elif 'linear' in source or 'jira' in content:
        return 'linear'
    elif 'salesforce' in source or 'sfdc' in content:
        return 'salesforce'
    elif 'hubspot' in source:
        return 'hubspot'
    # Personal apps
    elif 'imessage' in content or 'messages' in source:
        return 'messages'
    elif 'whatsapp' in source:
        return 'whatsapp'
    elif 'telegram' in source:
        return 'telegram'
    elif 'discord' in source:
        return 'discord'
    elif 'calendar' in content or 'event' in content:
        return 'calendar'
    elif 'reminder' in content or 'todo' in content:
        return 'reminders'
    elif 'spotify' in content or 'music' in content:
        return 'music'
    elif 'uber' in source or 'lyft' in source:
        return 'rideshare'
    elif 'doordash' in source or 'ubereats' in source:
        return 'delivery'
    else:
        return 'unknown'

def generate_automation(user_id, app_source, content):
    """Generate smart automation based on user patterns"""
    
    # In reality, this would use GPT-4/Claude to understand intent
    automations = {
        'slack': {
            'trigger': 'When mentioned in important channel',
            'action': 'Summarize thread, draft response, set reminder if needed'
        },
        'teams': {
            'trigger': 'When meeting starts',
            'action': 'Open notes, mute other apps, start transcript'
        },
        'outlook': {
            'trigger': 'When email from client received',
            'action': 'Create CRM activity, draft response, check calendar for conflicts'
        },
        'gmail': {
            'trigger': 'When invoice or receipt arrives',
            'action': 'Extract data, update spreadsheet, forward to accounting'
        },
        'notion': {
            'trigger': 'When page updated by teammate',
            'action': 'Summarize changes, update related docs, notify stakeholders'
        },
        'linear': {
            'trigger': 'When assigned new issue',
            'action': 'Create branch, update status, block calendar time'
        },
        'salesforce': {
            'trigger': 'When deal stage changes',
            'action': 'Update forecast, notify team, schedule next steps'
        },
        'messages': {
            'trigger': 'When partner texts about plans',
            'action': 'Check calendar, suggest times, add to shared list'
        },
        'whatsapp': {
            'trigger': 'When group chat gets active',
            'action': 'Summarize conversation, extract action items'
        },
        'calendar': {
            'trigger': '10 mins before meeting',
            'action': 'Pull up notes, previous meeting summary, and agenda'
        }
    }
    
    return automations.get(app_source, {
        'trigger': 'Custom trigger detected',
        'action': 'Learning your patterns...'
    })

def generate_next_shortcut(user_id, current_app):
    """Tell the user which shortcut to install next"""
    
    # Strategic expansion - enterprise first, then personal
    app_priority = [
        'slack',      # Enterprise communication
        'outlook',    # Enterprise email
        'teams',      # More enterprise comms
        'gmail',      # Personal/startup email
        'notion',     # Docs/wiki
        'linear',     # Task management
        'salesforce', # CRM
        'messages',   # Personal comms
        'whatsapp',   # International comms
        'calendar',   # Scheduling
        'reminders',  # Task tracking
    ]
    
    detected = USER_CONTEXTS[user_id]['apps_detected']
    for app in app_priority:
        if app not in detected:
            return {
                'app': app,
                'shortcut_url': f'https://lifeos.ai/shortcuts/{app}_{user_id[:8]}.shortcut',
                'value_prop': get_app_value_prop(app)
            }
    
    return {
        'app': 'advanced',
        'shortcut_url': f'https://lifeos.ai/shortcuts/poweruser_{user_id[:8]}.shortcut',
        'value_prop': 'Enable cross-app automation chains'
    }

def get_app_value_prop(app):
    """Compelling reason to connect each app"""
    props = {
        'slack': 'Never miss important messages - AI monitors and prioritizes for you',
        'outlook': 'Zero inbox in 5 mins/day - AI drafts all responses',
        'teams': 'Never take meeting notes again - AI captures everything',
        'gmail': 'Auto-organize receipts, invoices, and important emails',
        'notion': 'Keep all docs synced and updated automatically',
        'linear': 'Auto-update tickets based on commits and Slack discussions',
        'salesforce': 'Update CRM from any app - never log in again',
        'messages': 'AI responds to routine texts for you',
        'whatsapp': 'Summarize group chats you missed',
        'calendar': 'AI schedules your perfect day based on energy levels'
    }
    return props.get(app, f'Unlock {app} automation - 2 mins to setup')

@app.route('/generate_shortcut/<app_type>', methods=['GET'])
def generate_shortcut(app_type):
    """
    Dynamically generate shortcuts for different apps
    This would actually create .shortcut files
    """
    
    device_id = request.args.get('device_id', 'default')
    
    # In prod, this would generate actual .shortcut file
    # For now, return the structure
    
    shortcut_templates = {
        'slack': {
            'name': 'LifeOS Slack Intelligence',
            'actions': [
                'Open Slack',
                'Get recent messages from important channels',
                'Get DMs from VIPs',
                'Extract action items and questions',
                'Send to LifeOS webhook',
                'Show summary notification'
            ]
        },
        'outlook': {
            'name': 'LifeOS Outlook Assistant',
            'actions': [
                'Open Outlook',
                'Get unread emails',
                'Categorize by sender importance',
                'Extract meeting requests',
                'Send to LifeOS API',
                'Draft responses in drafts folder'
            ]
        },
        'teams': {
            'name': 'LifeOS Teams Monitor',
            'actions': [
                'Get Teams notifications',
                'Check meeting status',
                'Extract chat messages',
                'Send context to LifeOS',
                'Set focus mode during meetings'
            ]
        },
        'universal': {
            'name': 'LifeOS Universal Scanner',
            'actions': [
                'Get clipboard content',
                'Get current app',
                'Get location',
                'Get battery/focus mode',
                'Get calendar next event',
                'Send context bundle to LifeOS',
                'Execute returned automation'
            ]
        },
        'background_monitor': {
            'name': 'LifeOS Background Intelligence',
            'actions': [
                'Open webview to LifeOS dashboard',
                'Keep webview active (the trick!)',
                'Poll for new automations every 30s',
                'Execute shortcuts from server commands',
                'Send heartbeat with context'
            ]
        }
    }
    
    return jsonify({
        'shortcut_config': shortcut_templates.get(app_type, shortcut_templates['universal']),
        'webhook_url': f'https://lifeos.ai/intake',
        'device_token': hashlib.md5(device_id.encode()).hexdigest()
    })

@app.route('/user_dashboard/<user_id>', methods=['GET'])
def dashboard(user_id):
    """Show what we've learned about the user"""
    
    if user_id in USER_CONTEXTS:
        ctx = USER_CONTEXTS[user_id]
        apps = list(ctx['apps_detected'])
        
        # Calculate automation value
        if 'slack' in apps and 'outlook' in apps:
            time_saved = "~2 hours/day"
        elif any(app in apps for app in ['slack', 'teams', 'outlook']):
            time_saved = "~1 hour/day"
        else:
            time_saved = "~30 mins/day"
            
        return jsonify({
            'apps_connected': apps,
            'automations_available': len(apps) * 5,
            'intelligence_level': 'Learning' if len(apps) < 3 else 'Active',
            'time_saved_estimate': time_saved,
            'monthly_value': '$' + str(len(apps) * 500)  # Each app connection worth $500/mo
        })
    
    return jsonify({'status': 'No data yet'})

if __name__ == '__main__':
    print("🚀 LifeOS Backend Started")
    print("📱 Install shortcuts from: http://localhost:5000/generate_shortcut/<app_type>")
    print("📊 View your data at: http://localhost:5000/user_dashboard/<device_id>")
    app.run(debug=True, port=5000)