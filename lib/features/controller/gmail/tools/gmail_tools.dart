/// Gmail tool definitions for LLM function calling
const List<Map<String, dynamic>> gmailTools = [
  {
    'name': 'check_inbox',
    'description': 'Get the count of total and unread emails in the inbox. Use when user wants to know how many emails they have.',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'list_emails',
    'description': 'Display a list of emails from a folder. Shows sender, subject, date for each. Use to show inbox, sent mail, starred, drafts, spam, trash, or any label.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'folder': {
          'type': 'string',
          'description': 'Which folder: inbox, sent, starred, drafts, spam, trash, or a label name',
          'default': 'inbox'
        },
        'max_results': {
          'type': 'integer',
          'default': 20
        },
        'unread_only': {
          'type': 'boolean',
          'default': false
        }
      },
      'required': []
    }
  },
  {
    'name': 'list_unread_emails',
    'description': 'Display only unread/new emails from inbox.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'max_results': {
          'type': 'integer',
          'default': 20
        }
      },
      'required': []
    }
  },
  {
    'name': 'read_email',
    'description': 'Open and display the full content of a specific email. Takes a number (1=first, 2=second, etc). Use when user wants to read, open, view, or see a particular email.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'Position in current list: 1 for first email, 2 for second, etc.'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'search_emails',
    'description': 'Find emails matching criteria. Can search by sender, recipient, subject, content, date range, attachments, etc.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Gmail search query: from:, to:, subject:, has:attachment, after:, before:, or freetext'
        },
        'max_results': {
          'type': 'integer',
          'default': 20
        }
      },
      'required': ['query']
    }
  },
  {
    'name': 'send_email',
    'description': 'Compose and send a new email. Requires recipient, subject, and body.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'to': {
          'type': 'string',
          'description': 'Recipient - can be contact name or email address'
        },
        'subject': {
          'type': 'string'
        },
        'body': {
          'type': 'string'
        }
      },
      'required': ['to', 'subject', 'body']
    }
  },
  {
    'name': 'reply_to_email',
    'description': 'Send a reply to an existing email. Maintains the conversation thread.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer',
          'description': 'Which email to reply to (position in list)'
        },
        'body': {
          'type': 'string',
          'description': 'The reply message content'
        }
      },
      'required': ['email_number', 'body']
    }
  },
  {
    'name': 'delete_email',
    'description': 'Move an email to trash. Removes it from inbox.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'archive_email',
    'description': 'Archive an email - removes from inbox but keeps in All Mail for later reference.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'mark_as_read',
    'description': 'Mark an email as read, removing the unread indicator.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'apply_label',
    'description': 'Add a label/tag to an email for organization.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer'
        },
        'label': {
          'type': 'string'
        }
      },
      'required': ['email_number', 'label']
    }
  },
  {
    'name': 'remove_label',
    'description': 'Remove a label/tag from an email.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer'
        },
        'label': {
          'type': 'string'
        }
      },
      'required': ['email_number', 'label']
    }
  },
  {
    'name': 'list_labels',
    'description': 'Show all available labels/folders in the account.',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'add_contact',
    'description': 'Save a new contact to the addressbook with name and email.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string'
        },
        'email': {
          'type': 'string'
        }
      },
      'required': ['name', 'email']
    }
  },
  {
    'name': 'remove_contact',
    'description': 'Delete a contact from the addressbook.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string'
        }
      },
      'required': ['name']
    }
  },
  {
    'name': 'list_contacts',
    'description': 'Show all saved contacts in the addressbook.',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'find_contact',
    'description': 'Search for a contact by name in the addressbook.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string'
        }
      },
      'required': ['name']
    }
  },
  {
    'name': 'add_sender_to_contacts',
    'description': 'Save the sender of an email as a new contact.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'email_number': {
          'type': 'integer'
        },
        'nickname': {
          'type': 'string',
          'description': 'Optional: custom name for the contact'
        }
      },
      'required': ['email_number']
    }
  },
  {
    'name': 'open_attachment',
    'description': 'Open/view/download an attachment from the current email. Use when user wants to see, view, open, or download an attached file.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'attachment_index': {
          'type': 'integer',
          'description': 'Which attachment to open (1 for first, 2 for second). Defaults to 1.',
          'default': 1
        }
      },
      'required': []
    }
  },
  {
    'name': 'next_page',
    'description': 'Load the next page of emails when there are more results.',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'previous_page',
    'description': 'Go back to the previous page of emails.',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  }
];
