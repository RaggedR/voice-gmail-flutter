/// Gmail tool definitions for LLM function calling
const List<Map<String, dynamic>> gmailTools = [
  {
    'name': 'check_inbox',
    'description': 'Check how many unread emails are in the inbox',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'list_emails',
    'description': "List emails. Use 'folder' to specify: inbox (default), sent, starred, or a label name.",
    'input_schema': {
      'type': 'object',
      'properties': {
        'folder': {
          'type': 'string',
          'description': "Which folder/label: 'inbox' (default), 'sent', 'starred', 'drafts', 'spam', 'trash', or any label name",
          'default': 'inbox'
        },
        'max_results': {
          'type': 'integer',
          'description': 'Maximum number of emails to return (default 10)',
          'default': 10
        },
        'unread_only': {
          'type': 'boolean',
          'description': 'If true, only show unread emails.',
          'default': false
        }
      },
      'required': []
    }
  },
  {
    'name': 'list_unread_emails',
    'description': 'List only unread emails from inbox.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'max_results': {
          'type': 'integer',
          'description': 'Maximum number of emails to return (default 10)',
          'default': 10
        }
      },
      'required': []
    }
  },
  {
    'name': 'apply_label',
    'description': 'Apply a label to an email',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email (1 for first, etc.)'
        },
        'label': {
          'type': 'string',
          'description': "The label to apply (e.g., 'important', 'work', 'personal')"
        }
      },
      'required': ['email_number', 'label']
    }
  },
  {
    'name': 'remove_label',
    'description': 'Remove a label from an email',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email'
        },
        'label': {
          'type': 'string',
          'description': 'The label to remove'
        }
      },
      'required': ['email_number', 'label']
    }
  },
  {
    'name': 'list_labels',
    'description': 'List all available labels/folders',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'read_email',
    'description': 'Read the full content of a specific email by its position in the current list (1-indexed)',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email (1 for first, 2 for second, etc.)'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'search_emails',
    'description': 'Search for emails matching a query. Can search by sender, subject, content, date, etc.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': "Search query (e.g., 'from:john', 'subject:meeting', 'after:2024/01/01')"
        },
        'max_results': {
          'type': 'integer',
          'description': 'Maximum number of results (default 10)',
          'default': 10
        }
      },
      'required': ['query']
    }
  },
  {
    'name': 'send_email',
    'description': 'Send a new email to someone',
    'input_schema': {
      'type': 'object',
      'properties': {
        'to': {
          'type': 'string',
          'description': 'Recipient email address'
        },
        'subject': {
          'type': 'string',
          'description': 'Email subject line'
        },
        'body': {
          'type': 'string',
          'description': 'Email body content'
        }
      },
      'required': ['to', 'subject', 'body']
    }
  },
  {
    'name': 'reply_to_email',
    'description': 'Reply to an email by its position in the current list',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email to reply to'
        },
        'body': {
          'type': 'string',
          'description': 'Reply message content'
        }
      },
      'required': ['email_number', 'body']
    }
  },
  {
    'name': 'delete_email',
    'description': 'Move an email to trash by its position in the current list',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email to delete'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'archive_email',
    'description': 'Archive an email (remove from inbox but keep in All Mail)',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email to archive'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'mark_as_read',
    'description': 'Mark an email as read',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email to mark as read'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'add_contact',
    'description': 'Add a contact to the addressbook',
    'input_schema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': "The contact's name"
        },
        'email': {
          'type': 'string',
          'description': "The contact's email address"
        }
      },
      'required': ['name', 'email']
    }
  },
  {
    'name': 'remove_contact',
    'description': 'Remove a contact from the addressbook',
    'input_schema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': "The contact's name to remove"
        }
      },
      'required': ['name']
    }
  },
  {
    'name': 'list_contacts',
    'description': 'List all contacts in the addressbook',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'find_contact',
    'description': 'Search for a contact by name',
    'input_schema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': 'The name to search for'
        }
      },
      'required': ['name']
    }
  },
  {
    'name': 'add_sender_to_contacts',
    'description': "Add the sender of an email to contacts. Use after reading an email to save the sender's info.",
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'The position of the email whose sender to add (1 for first, etc.)'
        },
        'nickname': {
          'type': 'string',
          'description': 'Optional nickname for the contact (defaults to their name from email)'
        }
      },
      'required': ['email_number']
    }
  }
];
