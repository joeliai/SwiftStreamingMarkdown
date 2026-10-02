//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

// swiftlint:disable type_name

import UIKit

extension UIColor {
  enum Theme {
    enum Accent {
      static let Accent600 = UIColor.moduleColor("Colors/Copilot/Theme/Accent/600")
    }

    enum Background {
      enum Page {
        enum Chat {
          static let Flat = UIColor.moduleColor("Colors/Copilot/Theme/Background/Page/Chat/flat")
        }
      }
    }

    enum Component {
      enum Button {
        enum Foreground {
          static let Pressed = UIColor.moduleColor("Colors/Copilot/Theme/Component/Button/Foreground/pressed")
          static let Rest = UIColor.moduleColor("Colors/Copilot/Theme/Component/Button/Foreground/rest")
        }
      }

      enum CodeBlock {
        enum Background {
          static let Background750 = UIColor.moduleColor("Colors/Copilot/Theme/Component/CodeBlock/Background/750")
        }

        enum Foreground {
          static let FunctionParameter = UIColor.moduleColor("Colors/Copilot/Theme/Component/CodeBlock/Foreground/functionparameter")
          static let Header = UIColor.moduleColor("Colors/Copilot/Theme/Component/CodeBlock/Foreground/header")
        }
      }

      enum Table {
        enum Background {
          static let Header = UIColor.moduleColor("Colors/Copilot/Theme/Component/Table/Background/header")
        }
      }
    }

    enum Foreground {
      enum Primary {
        static let Primary450 = UIColor.moduleColor("Colors/Copilot/Theme/Foreground/Primary/450")
        static let Primary550 = UIColor.moduleColor("Colors/Copilot/Theme/Foreground/Primary/550")
        static let Primary650 = UIColor.moduleColor("Colors/Copilot/Theme/Foreground/Primary/650")
        static let Primary750 = UIColor.moduleColor("Colors/Copilot/Theme/Foreground/Primary/750")
        static let Primary800 = UIColor.moduleColor("Colors/Copilot/Theme/Foreground/Primary/800")
      }
    }

    enum Overlay {
      enum Black {
        static let Black5 = UIColor.moduleColor("Colors/Copilot/Theme/Overlay/Black/5")
      }
    }

    enum Stroke {
      enum Default {
        static let Default250 = UIColor.moduleColor("Colors/Copilot/Theme/Stroke/Default/250")
        static let Default300 = UIColor.moduleColor("Colors/Copilot/Theme/Stroke/Default/300")
      }

      enum Muted {
        static let Muted300 = UIColor.moduleColor("Colors/Copilot/Theme/Stroke/Muted/300")
      }
    }
  }
}
